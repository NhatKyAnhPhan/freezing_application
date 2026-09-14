package com.example.freezing_app
import kotlin.collections.*

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.app.ActivityManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku

class MainActivity : FlutterActivity() {
	companion object {
		private const val CHANNEL = "freezing_app/shizuku"
		private const val REQUEST_CODE = 1001
	}

	private var permissionResult: MethodChannel.Result? = null
	private lateinit var deviceStatsReader: DeviceStatsReader
	private var installedApplicationCache: List<ApplicationInfo>? = null
	private var disabledPackageCache: Set<String> = emptySet()
	private var restrictedPackageCache: MutableSet<String> = mutableSetOf()
	private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, _ ->
		if (requestCode == REQUEST_CODE) {
			permissionResult?.success(shizukuStatus())
			permissionResult = null
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		deviceStatsReader = DeviceStatsReader(applicationContext)
		Shizuku.addRequestPermissionResultListener(permissionListener)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "freezing_app/device").setMethodCallHandler { call, result ->
			when (call.method) {
				"cleanRam" -> cleanRam(result)
				"trimCaches" -> trimCaches(result)
				"getDeviceStats" -> {
					Thread {
						try {
							val manager = getSystemService(ACTIVITY_SERVICE) as? ActivityManager
							val processCount = manager?.runningAppProcesses?.size ?: 0
							val stats = deviceStatsReader.read(processCount, processCount)
							runOnUiThread { result.success(stats) }
						} catch (error: Throwable) {
							runOnUiThread { result.error("DEVICE_STATS", error.message, null) }
						}
					}.start()
				}
				"getRunningAppCount" -> result.success(0)
				else -> result.notImplemented()
			}
		}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"getShizukuStatus" -> result.success(shizukuStatus())
				"requestShizukuPermission" -> requestShizukuPermission(result)
				"getInstalledApps" -> getInstalledApps(result)
				"getInstalledAppsPage" -> getInstalledAppsPage(call, result)
				"setFrozen" -> {
					val packageName = call.argument<String>("packageName")
					val frozen = call.argument<Boolean>("frozen") ?: false
					if (packageName == null) {
						result.error("INVALID_ARGUMENT", "packageName is required", null)
					} else {
						setFrozen(packageName, frozen, result)
					}
				}
				"setFrozenBatch" -> {
					val packageNames = call.argument<List<String>>("packageNames") ?: emptyList()
					val frozen = call.argument<Boolean>("frozen") ?: false
					setFrozenBatch(packageNames, frozen, result)
				}
				"killBackgroundApps" -> {
					val packageNames = call.argument<List<String>>("packageNames") ?: emptyList()
					killBackgroundApps(packageNames, result)
				}
				"getRunningPackages" -> getRunningPackages(result)
				else -> result.notImplemented()
			}
		}
	}

	private fun shizukuStatus(): String {
		if (!Shizuku.pingBinder()) return "unavailable"
		return if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) "granted" else "denied"
	}

	private fun requestShizukuPermission(result: MethodChannel.Result) {
		when (shizukuStatus()) {
			"unavailable" -> result.success("unavailable")
			"granted" -> result.success("granted")
			else -> {
				permissionResult = result
				Shizuku.requestPermission(REQUEST_CODE)
			}
		}
	}

	private fun getInstalledApps(result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		Thread {
			try {
				val disabledPackages = runShell("pm list packages -d")
					.lineSequence()
					.map { it.removePrefix("package:").trim() }
					.filter { it.isNotEmpty() }
					.toSet()
				val apps = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
					.filter { it.packageName != packageName }
					.sortedBy { it.loadLabel(packageManager).toString().lowercase() }
					.map {
						mapOf(
							"name" to it.loadLabel(packageManager).toString(),
							"packageName" to it.packageName,
							"isFrozen" to disabledPackages.contains(it.packageName),
							"isSystem" to ((it.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
							"iconBytes" to iconBytes(it.loadIcon(packageManager)),
						)
					}
				runOnUiThread { result.success(apps) }
			} catch (error: Exception) {
				runOnUiThread { result.error("SHIZUKU_COMMAND", error.message, null) }
			}
		}.start()
	}

	private fun getInstalledAppsPage(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		val offset = (call.argument<Int>("offset") ?: 0).coerceAtLeast(0)
		val limit = (call.argument<Int>("limit") ?: 24).coerceIn(1, 48)
		val refresh = call.argument<Boolean>("refresh") ?: false
		Thread {
			try {
				if (refresh || installedApplicationCache == null) {
					disabledPackageCache = runShell("pm list packages -d")
						.lineSequence()
						.map { it.removePrefix("package:").trim() }
						.filter { it.isNotEmpty() }
						.toSet()
					restrictedPackageCache = readRestrictedPackages().toMutableSet()
					installedApplicationCache = packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
						.filter { it.packageName != packageName }
						.sortedBy { it.loadLabel(packageManager).toString().lowercase() }
				}
				val cached = installedApplicationCache.orEmpty()
				val page = cached.drop(offset).take(limit).map { applicationInfo ->
					mapOf(
						"name" to applicationInfo.loadLabel(packageManager).toString(),
						"packageName" to applicationInfo.packageName,
						"isFrozen" to (disabledPackageCache + restrictedPackageCache).contains(applicationInfo.packageName),
						"isSystem" to ((applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
						"iconBytes" to iconBytes(applicationInfo.loadIcon(packageManager)),
					)
				}
				runOnUiThread { result.success(page) }
			} catch (error: Exception) {
				runOnUiThread { result.error("SHIZUKU_COMMAND", error.message, null) }
			}
		}.start()
	}

	private fun cleanRam(result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		Thread {
			try {
				val before = memorySnapshot()
				runShell("am kill-all")
				Thread.sleep(350L)
				val after = memorySnapshot()
				runOnUiThread { result.success(mapOf("succeeded" to true, "beforeUsedBytes" to before.first, "afterUsedBytes" to after.first, "freedBytes" to (before.first - after.first).coerceAtLeast(0.0), "killedApps" to 0, "trimmedProcesses" to 0, "durationMs" to 350, "method" to "shizuku")) }
			} catch (error: Exception) {
				runOnUiThread { result.success(mapOf("succeeded" to false, "beforeUsedBytes" to 0.0, "afterUsedBytes" to 0.0, "freedBytes" to 0.0, "killedApps" to 0, "trimmedProcesses" to 0, "durationMs" to 0, "method" to "none")) }
			}
		}.start()
	}

	private fun trimCaches(result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.success(false)
			return
		}
		Thread { runCatching { runShell("pm trim-caches 0") }.onSuccess { runOnUiThread { result.success(true) } }.onFailure { runOnUiThread { result.success(false) } } }.start()
	}

	private fun memorySnapshot(): Pair<Double, Double> {
		val info = ActivityManager.MemoryInfo()
		(getSystemService(ACTIVITY_SERVICE) as? ActivityManager)?.getMemoryInfo(info)
		return Pair((info.totalMem - info.availMem).toDouble(), info.totalMem.toDouble())
	}

	private fun iconBytes(drawable: Drawable): ByteArray {
		val size = 48
		val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
		val canvas = Canvas(bitmap)
		drawable.setBounds(0, 0, size, size)
		drawable.draw(canvas)
		val output = ByteArrayOutputStream()
		bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
		bitmap.recycle()
		return output.toByteArray()
	}

	private fun setFrozen(packageName: String, frozen: Boolean, result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		Thread {
			try {
				val command = if (frozen) {
					"cmd appops set $packageName RUN_ANY_IN_BACKGROUND ignore; cmd appops set $packageName RUN_IN_BACKGROUND ignore"
				} else {
					val restore = if (disabledPackageCache.contains(packageName)) "pm enable $packageName; " else ""
					"${restore}cmd appops set $packageName RUN_ANY_IN_BACKGROUND allow; cmd appops set $packageName RUN_IN_BACKGROUND allow"
				}
				runShell(command)
				if (frozen) restrictedPackageCache.add(packageName) else restrictedPackageCache.remove(packageName)
				disabledPackageCache = disabledPackageCache - packageName
				runOnUiThread { result.success(true) }
			} catch (error: Exception) {
				runOnUiThread { result.error("SHIZUKU_COMMAND", error.message, null) }
			}
		}.start()
	}

	/**
	 * Applies the same freeze state to many packages in one background thread.
	 * Unlike [setFrozen], a single package failing does not abort the rest —
	 * the caller (FreezerProvider) only updates local state for the packages
	 * that come back in the result list.
	 */
	private fun setFrozenBatch(packageNames: List<String>, frozen: Boolean, result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		if (packageNames.isEmpty()) {
			result.success(emptyList<String>())
			return
		}
		Thread {
			val updated = mutableListOf<String>()
			for (targetPackage in packageNames) {
				try {
					val command = if (frozen) {
						"cmd appops set $targetPackage RUN_ANY_IN_BACKGROUND ignore; cmd appops set $targetPackage RUN_IN_BACKGROUND ignore"
					} else {
						val restore = if (disabledPackageCache.contains(targetPackage)) "pm enable $targetPackage; " else ""
						"${restore}cmd appops set $targetPackage RUN_ANY_IN_BACKGROUND allow; cmd appops set $targetPackage RUN_IN_BACKGROUND allow"
					}
					runShell(command)
					if (frozen) restrictedPackageCache.add(targetPackage) else restrictedPackageCache.remove(targetPackage)
					disabledPackageCache = disabledPackageCache - targetPackage
					updated.add(targetPackage)
				} catch (error: Exception) {
					// Bỏ qua package lỗi (ví dụ app hệ thống không cho appops can thiệp),
					// tiếp tục xử lý các package còn lại thay vì làm hỏng cả batch.
				}
			}
			runOnUiThread { result.success(updated) }
		}.start()
	}

	/** Force-stops every package in [packageNames]; returns how many succeeded. */
	private fun killBackgroundApps(packageNames: List<String>, result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		if (packageNames.isEmpty()) {
			result.success(0)
			return
		}
		Thread {
			var killed = 0
			for (targetPackage in packageNames) {
				try {
					runShell("am force-stop $targetPackage")
					killed++
				} catch (error: Exception) {
					// Bỏ qua package lỗi.
				}
			}
			runOnUiThread { result.success(killed) }
		}.start()
	}

	/** Package names from the process table that look like real apps, not kernel threads. */
	private fun getRunningPackages(result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		Thread {
			try {
				val running = runShell("ps -A -o NAME")
					.lineSequence()
					.map { it.trim() }
					.filter { it.isNotEmpty() && it.contains('.') && !it.startsWith("[") && !it.startsWith("/") && !it.startsWith("-") }
					.map { if (it.contains(':')) it.substringBefore(':') else it }
					.toSet()
					.toList()
				runOnUiThread { result.success(running) }
			} catch (error: Exception) {
				runOnUiThread { result.error("SHIZUKU_COMMAND", error.message, null) }
			}
		}.start()
	}

	private fun readRestrictedPackages(): Set<String> {
		return try {
			runShell("cmd appops query-op RUN_ANY_IN_BACKGROUND ignore")
				.lineSequence()
				.mapNotNull { Regex("([A-Za-z0-9_]+\\.)+[A-Za-z0-9_]+").find(it)?.value }
				.toSet()
		} catch (error: Throwable) {
			emptySet()
		}
	}

	private fun runShell(command: String): String {
		val process = Shizuku.newProcess(arrayOf("sh", "-c", command), null, null)
		val output = process.inputStream.bufferedReader().use { it.readText() }
		val error = process.errorStream.bufferedReader().use { it.readText() }
		val exitCode = process.waitFor()
		if (exitCode != 0) throw IllegalStateException(error.ifBlank { output })
		return output
	}

	private fun isUserFacingApp(applicationInfo: ApplicationInfo): Boolean {
		return packageManager.getLaunchIntentForPackage(applicationInfo.packageName) != null
	}

	override fun onDestroy() {
		Shizuku.removeRequestPermissionResultListener(permissionListener)
		super.onDestroy()
	}
}