package com.example.freezing_app
import kotlin.collections.*

import android.app.ActivityManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import java.io.File

/**
 * Collects CPU / RAM / battery / storage telemetry for the dashboard.
 *
 * Every probe is best-effort: `/proc` and `/sys` may be unreadable on hardened
 * ROMs, so each getter falls back to a sensible default instead of throwing.
 */
class DeviceStatsReader(private val context: Context) {
	private var lastTotalTicks = 0L
	private var lastIdleTicks = 0L
	private var lastUsagePercent = 0.0
	private var lastRxBytes = -1L
	private var lastTxBytes = -1L
	private var lastNetworkTimestamp = 0L
	private var designCapacityLoaded = false
	private var cachedDesignCapacityMah = 0.0
	private var fullCapacityLoaded = false
	private var cachedFullCapacityMah = 0.0

	fun read(runningAppCount: Int, processCount: Int): Map<String, Any?> {
		val cpu = readCpu(processCount)
		val gpu = try {
			readGpu()
		} catch (error: Throwable) {
			mapOf("name" to "", "usagePercent" to -1.0, "currentFrequencyMhz" to 0, "temperatureCelsius" to null)
		}
		val network = try {
			readNetwork()
		} catch (error: Throwable) {
			mapOf("downloadMbps" to 0.0, "uploadMbps" to 0.0, "linkDownMbps" to 0, "linkUpMbps" to 0)
		}
		return mapOf(
			"timestamp" to System.currentTimeMillis(),
			"cpu" to cpu,
			"gpu" to gpu,
			"network" to network,
			"ram" to readRam(),
			"battery" to readBattery(),
			"storage" to readStorage(),
			"runningAppCount" to runningAppCount,
		)
	}

	// ------------------------------------------------------------------ CPU

	private fun readCpu(processCount: Int): Map<String, Any?> {
		val usage = readCpuUsage()
		return mapOf(
			"usagePercent" to usage,
			"coreCount" to Runtime.getRuntime().availableProcessors(),
			"maxFrequencyMhz" to maxCpuFrequencyMhz(),
			"currentFrequencyMhz" to currentCpuFrequencyMhz(),
			"temperatureCelsius" to cpuTemperatureCelsius(),
			"processCount" to processCount,
			"loadAverage" to loadAverage(),
			"architecture" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
			"model" to cpuModel(),
		)
	}

	private fun cpuModel(): String {
		val socModel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else ""
		if (socModel.isNotBlank()) return socModel
		val cpuInfo = readFile("/proc/cpuinfo") ?: return Build.HARDWARE
		return cpuInfo.lineSequence()
			.firstOrNull { it.startsWith("Hardware") || it.startsWith("Processor") }
			?.substringAfter(':')?.trim()?.takeIf(String::isNotBlank)
			?: Build.HARDWARE
	}

	/**
	 * Aggregate utilisation derived from the delta between two `/proc/stat`
	 * samples. The first call after start-up only primes the baseline.
	 */
	private fun readCpuUsage(): Double {
		val line = firstLine("/proc/stat")
		if (line == null || !line.startsWith("cpu ")) return loadAverageFallback()
		val parts = line.trim().split(Regex("\\s+"))
		if (parts.size < 6) return loadAverageFallback()

		var total = 0L
		var idle = 0L
		for (index in 1 until parts.size) {
			val value = parts[index].toLongOrNull() ?: continue
			total += value
			// idle + iowait count as non-busy time.
			if (index == 4 || index == 5) idle += value
		}
		if (total == 0L) return loadAverageFallback()

		val deltaTotal = total - lastTotalTicks
		val deltaIdle = idle - lastIdleTicks
		lastTotalTicks = total
		lastIdleTicks = idle

		if (deltaTotal <= 0L || deltaIdle < 0L) return loadAverageFallback()
		val busy = (deltaTotal - deltaIdle).toDouble() / deltaTotal.toDouble() * 100.0
		if (busy <= 0.01) return loadAverageFallback()
		lastUsagePercent = busy.coerceIn(0.0, 100.0)
		return lastUsagePercent
	}

	private fun loadAverageFallback(): Double {
		val average = loadAverage()
		val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
		val estimate = (average / cores.toDouble() * 100.0).coerceIn(0.0, 100.0)
		if (estimate > 0.0) lastUsagePercent = estimate
		return lastUsagePercent
	}

	/** Highest frequency advertised across all cores, in MHz. */
	private fun maxCpuFrequencyMhz(): Int {
		var best = 0
		for (index in 0 until 16) {
			val path = "/sys/devices/system/cpu/cpu$index/cpufreq/cpuinfo_max_freq"
			val khz = readFile(path)?.trim()?.toIntOrNull() ?: continue
			val mhz = khz / 1000
			if (mhz > best) best = mhz
		}
		return best
	}

	/** Median of the current per-core frequencies, in MHz. */
	private fun currentCpuFrequencyMhz(): Int {
		val samples = ArrayList<Int>()
		for (index in 0 until 16) {
			val path = "/sys/devices/system/cpu/cpu$index/cpufreq/scaling_cur_freq"
			val khz = readFile(path)?.trim()?.toIntOrNull() ?: continue
			if (khz > 0) samples.add(khz / 1000)
		}
		if (samples.isEmpty()) return 0
		samples.sort()
		return samples[samples.size / 2]
	}

	/**
	 * SoC temperature from the thermal zones. Zones whose name mentions the CPU
	 * or the SoC are preferred, otherwise the first plausible reading wins.
	 */
	private fun cpuTemperatureCelsius(): Double? {
		val hints = listOf("cpu", "soc", "gpu", "kgsl", "gpuss", "gfx", "tsens", "ap", "cluster", "big", "little")
		var fallback: Double? = null
		for (index in 0 until 32) {
			val zone = "/sys/class/thermal/thermal_zone$index"
			val raw = readFile("$zone/temp")?.trim()?.toDoubleOrNull() ?: continue
			val value = normaliseTemperature(raw)
			if (value == null || value < 5.0 || value > 120.0) continue
			val name = (readFile("$zone/type") ?: "").lowercase()
			if (hints.any { name.contains(it) }) return value
			if (fallback == null) fallback = value
		}
		return fallback
	}

	// --------------------------------------------------------------- GPU

	private fun readGpu(): Map<String, Any?> {
		val name = listOf(
			"/sys/class/kgsl/kgsl-3d0/gpu_model",
			"/sys/class/misc/mali0/device/gpuinfo",
			"/sys/devices/platform/gpu.0/gpu_model",
		).asSequence()
			.mapNotNull { readFile(it)?.trim()?.takeIf(String::isNotEmpty) }
			.firstOrNull() ?: ""
		val frequencyRaw = listOf(
			"/sys/class/kgsl/kgsl-3d0/devfreq/cur_freq",
			"/sys/class/misc/mali0/device/cur_freq",
		).asSequence()
			.mapNotNull { readFile(it)?.trim()?.toLongOrNull() }
			.firstOrNull() ?: 0L
		val usage = listOf(
			"/sys/class/kgsl/kgsl-3d0/gpu_busy_percentage",
			"/sys/class/kgsl/kgsl-3d0/gpu_busy_percent",
			"/sys/class/kgsl/kgsl-3d0/devfreq/gpu_busy_percentage",
		).asSequence()
			.mapNotNull { readFile(it)?.trim()?.replace("%", "")?.toDoubleOrNull() }
			.firstOrNull() ?: -1.0
		return mapOf(
			"name" to name,
			"usagePercent" to if (usage < 0) -1.0 else usage.coerceIn(0.0, 100.0),
			"currentFrequencyMhz" to (if (frequencyRaw > 100000L) frequencyRaw / 1000L else frequencyRaw).toInt(),
			"temperatureCelsius" to gpuTemperatureCelsius(),
		)
	}

	private fun gpuTemperatureCelsius(): Double? {
		for (index in 0 until 32) {
			val zone = "/sys/class/thermal/thermal_zone$index"
			val type = (readFile("$zone/type") ?: "").lowercase()
			if (!listOf("gpu", "kgsl", "gpuss", "gfx").any { type.contains(it) }) continue
			val raw = readFile("$zone/temp")?.trim()?.toDoubleOrNull() ?: continue
			val value = normaliseTemperature(raw)
			if (value != null && value in 5.0..120.0) return value
		}
		return null
	}

	// ------------------------------------------------------------ network

	private fun readNetwork(): Map<String, Any?> {
		val now = System.currentTimeMillis()
		val rx = TrafficStats.getTotalRxBytes()
		val tx = TrafficStats.getTotalTxBytes()
		var downloadMbps = 0.0
		var uploadMbps = 0.0
		if (lastNetworkTimestamp > 0L && rx >= 0L && tx >= 0L) {
			val seconds = (now - lastNetworkTimestamp).coerceAtLeast(1L) / 1000.0
			downloadMbps = ((rx - lastRxBytes).coerceAtLeast(0L) * 8.0 / seconds) / 1_000_000.0
			uploadMbps = ((tx - lastTxBytes).coerceAtLeast(0L) * 8.0 / seconds) / 1_000_000.0
		}
		lastRxBytes = rx
		lastTxBytes = tx
		lastNetworkTimestamp = now
		val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
		val capabilities = connectivity?.activeNetwork?.let { connectivity.getNetworkCapabilities(it) }
		return mapOf(
			"downloadMbps" to downloadMbps,
			"uploadMbps" to uploadMbps,
			"linkDownMbps" to ((capabilities?.linkDownstreamBandwidthKbps ?: 0) / 1000),
			"linkUpMbps" to ((capabilities?.linkUpstreamBandwidthKbps ?: 0) / 1000),
		)
	}

	/** Three-digit millidegrees are divided down to degrees Celsius. */
	private fun normaliseTemperature(raw: Double): Double? = when {
		raw > 10000 -> raw / 1000.0
		raw > 1000 -> raw / 10.0
		else -> raw
	}

	private fun loadAverage(): Double {
		val line = firstLine("/proc/loadavg") ?: return 0.0
		return line.trim().split(" ").firstOrNull()?.toDoubleOrNull() ?: 0.0
	}

	// ------------------------------------------------------------------ RAM

	private fun readRam(): Map<String, Any?> {
		val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
		val memoryInfo = ActivityManager.MemoryInfo()
		if (activityManager != null) {
			activityManager.getMemoryInfo(memoryInfo)
		}
		val total = memoryInfo.totalMem
		val available = memoryInfo.availMem
		val used = (total - available).coerceAtLeast(0L)
		val meminfo = readMemInfo()
		val cached = meminfo["Cached"] ?: estimateCached(available)

		return mapOf(
			"totalBytes" to total.toDouble(),
			"usedBytes" to used.toDouble(),
			"availableBytes" to available.toDouble(),
			"cachedBytes" to cached,
			"swapTotalBytes" to (meminfo["SwapTotal"] ?: 0.0),
			"swapUsedBytes" to ((meminfo["SwapTotal"] ?: 0.0) - (meminfo["SwapFree"] ?: 0.0)).coerceAtLeast(0.0),
			"isLowMemory" to memoryInfo.lowMemory,
			"thresholdBytes" to memoryInfo.threshold.toDouble(),
		)
	}

	/** When `/proc/meminfo` is unreadable, assume a third of free RAM is cache. */
	private fun estimateCached(available: Long): Double = available * 0.35

	private fun readMemInfo(): Map<String, Double> {
		val content = readFile("/proc/meminfo") ?: return emptyMap()
		val values = HashMap<String, Double>()
		for (line in content.lineSequence()) {
			val separator = line.indexOf(':')
			if (separator <= 0) continue
			val key = line.substring(0, separator).trim()
			val raw = line.substring(separator + 1).trim().split(Regex("\\s+")).firstOrNull() ?: continue
			val kilobytes = raw.toDoubleOrNull() ?: continue
			values[key] = kilobytes * 1024.0
		}
		val cached = (values["Cached"] ?: 0.0) + (values["Buffers"] ?: 0.0)
		val readable = HashMap<String, Double>()
		readable["Cached"] = cached
		values["SwapTotal"]?.let { readable["SwapTotal"] = it }
		values["SwapFree"]?.let { readable["SwapFree"] = it }
		return readable
	}

	// -------------------------------------------------------------- storage

	private fun readStorage(): Map<String, Any?> {
		val stat = StatFs(Environment.getDataDirectory().path)
		val total = stat.blockCountLong * stat.blockSizeLong
		val available = stat.availableBlocksLong * stat.blockSizeLong
		val used = (total - available).coerceAtLeast(0L)
		return mapOf(
			"totalBytes" to total.toDouble(),
			"usedBytes" to used.toDouble(),
			"availableBytes" to available.toDouble(),
			"dataPartitionBytes" to total.toDouble(),
			"cacheBytes" to cacheDirectorySize(),
		)
	}

	private fun cacheDirectorySize(): Double {
		return try {
			context.cacheDir.walkTopDown().filter { it.isFile }.sumOf { it.length().toDouble() }
		} catch (error: Throwable) {
			0.0
		}
	}

	// -------------------------------------------------------------- battery

	private fun readBattery(): Map<String, Any?> {
		val manager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
		val status = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

		val level = status?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
		val scale = status?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
		val percent = if (level >= 0 && scale > 0) level * 100 / scale else 0

		val statusCode = status?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
		val plugged = status?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
		val charging = statusCode == BatteryManager.BATTERY_STATUS_CHARGING ||
			statusCode == BatteryManager.BATTERY_STATUS_FULL ||
			plugged != 0

		val temperatureRaw = status?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
		val temperature = temperatureRaw / 10.0
		val voltage = status?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0
		val health = healthLabel(status?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1)
		val technology = status?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY) ?: ""

		val currentNowMicroAmps = manager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW) ?: 0
		val chargeCounterMicroAh = manager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER) ?: 0
		val currentMilliAmps = normaliseMicro(currentNowMicroAmps, fallbackDivisor = 1000.0)
		val chargeCounterMah = normaliseMicro(chargeCounterMicroAh, fallbackDivisor = 1000.0)
		val capacityMah = batteryCapacityMah(chargeCounterMah, percent)
		val designCapacityMah = cachedBatteryCapacity(listOf(
			"/sys/class/power_supply/battery/charge_full_design",
			"/sys/class/power_supply/bms/charge_full_design",
			"/sys/class/power_supply/battery/capacity_full_design",
		))
		val fullChargeCapacityMah = cachedBatteryCapacity(listOf(
			"/sys/class/power_supply/battery/charge_full",
			"/sys/class/power_supply/bms/charge_full",
			"/sys/class/power_supply/battery/capacity_full",
		))
		val measuredCapacityMah = estimateFullCapacity(chargeCounterMah, percent)
		val referenceCapacityMah = batteryReferenceCapacity(designCapacityMah, measuredCapacityMah, percent)
		val actualCapacityMah = if (fullChargeCapacityMah > 0.0) fullChargeCapacityMah else measuredCapacityMah

		return mapOf(
			"levelPercent" to percent,
			"isCharging" to (charging && statusCode != BatteryManager.BATTERY_STATUS_FULL),
			"isPlugged" to (plugged != 0),
			"plugType" to plugLabel(plugged),
			"temperatureCelsius" to temperature,
			"voltageMilliVolts" to voltage,
			"currentMilliAmps" to currentMilliAmps,
			"health" to health,
			"technology" to technology,
			"chargeCounterMah" to chargeCounterMah,
			"capacityMah" to if (actualCapacityMah > 0.0) actualCapacityMah else capacityMah,
			"designCapacityMah" to designCapacityMah,
			"fullChargeCapacityMah" to actualCapacityMah,
			"measuredCapacityMah" to measuredCapacityMah,
			"referenceCapacityMah" to referenceCapacityMah,
			"estimatedRemainingMinutes" to estimateMinutes(chargeCounterMah, currentMilliAmps, percent, charging),
			"estimatedFullMinutes" to null,
		)
	}

	private fun estimateFullCapacity(chargeCounterMah: Double, percent: Int): Double {
		if (chargeCounterMah <= 0.0 || percent !in 5..100) return 0.0
		val estimate = chargeCounterMah * 100.0 / percent
		return if (estimate in 500.0..30000.0) estimate else 0.0
	}

	private fun batteryReferenceCapacity(design: Double, measured: Double, percent: Int): Double {
		if (design > 0.0) return design
		val preferences = context.getSharedPreferences("battery_telemetry", Context.MODE_PRIVATE)
		val saved = preferences.getFloat("reference_capacity_mah", 0f).toDouble()
		if (measured > 0.0 && percent >= 80) {
			val reference = maxOf(saved, measured)
			if (reference > saved) {
				preferences.edit().putFloat("reference_capacity_mah", reference.toFloat()).apply()
			}
			return reference
		}
		return saved
	}

	private fun readCapacity(paths: List<String>): Double {
		for (path in paths) {
			val raw = readFile(path)?.trim()?.toDoubleOrNull() ?: continue
			val capacity = if (raw > 100000.0) raw / 1000.0 else raw
			if (capacity in 500.0..30000.0) return capacity
		}
		return 0.0
	}

	private fun cachedBatteryCapacity(paths: List<String>): Double {
		val isDesign = paths.any { it.contains("design") }
		if (isDesign && designCapacityLoaded) return cachedDesignCapacityMah
		if (!isDesign && fullCapacityLoaded) return cachedFullCapacityMah
		var capacity = readCapacity(paths)
		if (capacity <= 0.0 && ShizukuShell.isGranted()) {
			val command = paths.joinToString(" ; ") { "cat $it 2>/dev/null && exit" }
			val output = ShizukuShell.run(command)
			capacity = output.output.trim().lineSequence()
				.mapNotNull { it.trim().toDoubleOrNull() }
				.map { if (it > 100000.0) it / 1000.0 else it }
				.firstOrNull { it in 500.0..30000.0 } ?: 0.0
		}
		if (capacity <= 0.0 && ShizukuShell.isGranted()) {
			val dump = ShizukuShell.run("dumpsys battery").output
			val key = if (isDesign) "(design|full)[ _-]*capacity" else "full[ _-]*charge[ _-]*capacity"
			capacity = Regex("(?im)$key\\s*[:=]\\s*(\\d+)")
				.find(dump)?.groupValues?.getOrNull(1)?.toDoubleOrNull() ?: 0.0
		}
		if (isDesign) {
			designCapacityLoaded = true
			cachedDesignCapacityMah = capacity
		} else {
			fullCapacityLoaded = true
			cachedFullCapacityMah = capacity
		}
		return capacity
	}

	/** Reads design/full charge capacity where the vendor exposes it. */
	private fun batteryCapacityMah(chargeCounterMah: Double, percent: Int): Double {
		val paths = listOf(
			"/sys/class/power_supply/battery/charge_full_design",
			"/sys/class/power_supply/battery/charge_full",
			"/sys/class/power_supply/bms/charge_full_design",
			"/sys/class/power_supply/bms/charge_full",
			"/sys/class/power_supply/battery/capacity_full_design",
			"/sys/class/power_supply/battery/capacity_full",
		)
		for (path in paths) {
			val raw = readFile(path)?.trim()?.toDoubleOrNull() ?: continue
			val capacity = if (raw > 100000.0) raw / 1000.0 else raw
			if (capacity in 500.0..30000.0) return capacity
		}
		if (chargeCounterMah > 0.0 && percent in 5..100) {
			val estimate = chargeCounterMah * 100.0 / percent
			if (estimate in 500.0..30000.0) return estimate
		}
		return 0.0
	}

	/**
	 * Some vendors report microamps, others milliamps. Values above 10000 are
	 * assumed to be microamps.
	 */
	private fun normaliseMicro(value: Int, fallbackDivisor: Double): Double {
		if (value == 0) return 0.0
		val magnitude = Math.abs(value).toDouble()
		return if (magnitude > 10000.0) magnitude / 1000.0 else magnitude
	}

	/**
	 * Remaining minutes from the fuel gauge when available, otherwise from a
	 * coarse linear model of the battery percentage.
	 */
	private fun estimateMinutes(
		chargeCounterMah: Double,
		currentMilliAmps: Double,
		percent: Int,
		charging: Boolean,
	): Int? {
		if (charging) return null
		if (chargeCounterMah > 0.0 && currentMilliAmps > 1.0) {
			val hours = chargeCounterMah / currentMilliAmps
			val minutes = (hours * 60.0).toInt()
			if (minutes in 1..2880) return minutes
		}
		if (percent <= 0) return null
		// Assume a 5000 mAh pack drawing 400 mA on average.
		val remainingMah = 5000.0 * percent / 100.0
		val minutes = (remainingMah / 400.0 * 60.0).toInt()
		return if (minutes in 1..2880) minutes else null
	}

	private fun plugLabel(plugged: Int): String = when (plugged) {
		BatteryManager.BATTERY_PLUGGED_AC -> "ac"
		BatteryManager.BATTERY_PLUGGED_USB -> "usb"
		BatteryManager.BATTERY_PLUGGED_WIRELESS -> "wireless"
		else -> "unplugged"
	}

	private fun healthLabel(health: Int): String = when (health) {
		BatteryManager.BATTERY_HEALTH_GOOD -> "good"
		BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
		BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
		BatteryManager.BATTERY_HEALTH_COLD -> "cold"
		BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "over_voltage"
		else -> "unknown"
	}

	// -------------------------------------------------------------- helpers

	private fun firstLine(path: String): String? =
		readFile(path)?.lineSequence()?.firstOrNull { it.isNotBlank() }

	private fun readFile(path: String): String? {
		try {
			val file = File(path)
			if (file.exists()) return file.readText()
		} catch (error: Throwable) {
			// Fall through to the procfs command fallback below.
		}
		if (!path.startsWith("/proc/")) return null
		val localProcessOutput = try {
			Runtime.getRuntime().exec(arrayOf("cat", path)).inputStream
				.bufferedReader().use { it.readText().takeIf(String::isNotBlank) }
		} catch (error: Throwable) {
			null
		}
		if (localProcessOutput != null) return localProcessOutput
		return if (ShizukuShell.isGranted()) {
			ShizukuShell.run("cat $path").takeIf { it.isSuccess }?.output
		} else {
			null
		}
	}
}
