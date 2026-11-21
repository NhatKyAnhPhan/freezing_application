package com.example.freezing_app

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.BatteryManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import rikka.shizuku.Shizuku

data class ManagedApp(
    val name: String,
    val packageName: String,
    val frozen: Boolean,
    val system: Boolean,
    val running: Boolean = false,
)

class FreezerRepository(private val context: Context) {
    private val packageManager = context.packageManager
    private val deviceStatsReader = DeviceStatsReader(context)
    private var applications: List<ApplicationInfo> = emptyList()
    private var disabledPackages: Set<String> = emptySet()
    private var restrictedPackages: MutableSet<String> = mutableSetOf()

    fun status(): String = try {
        if (!Shizuku.pingBinder()) "unavailable"
        else if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) "granted" else "denied"
    } catch (_: Throwable) { "unavailable" }

    suspend fun loadApps(refresh: Boolean = false): List<ManagedApp> = withContext(Dispatchers.IO) {
        check(status() == "granted") { "Hãy khởi động Shizuku và cấp quyền để quản lý ứng dụng." }
        if (refresh || applications.isEmpty()) {
            disabledPackages = shell("pm list packages -d").lineSequence()
                .map { it.removePrefix("package:").trim() }.filter(String::isNotBlank).toSet()
            restrictedPackages = shell("cmd appops query-op RUN_ANY_IN_BACKGROUND ignore")
                .lineSequence().mapNotNull { Regex("([A-Za-z0-9_]+\\.)+[A-Za-z0-9_]+").find(it)?.value }
                .toMutableSet()
            @Suppress("DEPRECATION")
            applications = if (Build.VERSION.SDK_INT >= 33) packageManager.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()))
            else packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
            applications = applications.filter { it.packageName != context.packageName }
                .sortedBy { it.loadLabel(packageManager).toString().lowercase() }
        }
        val running = runningPackagesUnsafe()
        applications.map { info ->
            ManagedApp(
                name = info.loadLabel(packageManager).toString(),
                packageName = info.packageName,
                frozen = info.packageName in disabledPackages || info.packageName in restrictedPackages,
                system = info.flags and ApplicationInfo.FLAG_SYSTEM != 0,
                running = info.packageName in running,
            )
        }
    }

    suspend fun toggle(app: ManagedApp): Boolean = withContext(Dispatchers.IO) {
        val packageName = safePackage(app.packageName) ?: return@withContext false
        if (app.frozen) unfreezeOne(packageName) else freezeOne(packageName)
    }

    suspend fun freeze(packages: List<String>): List<String> = withContext(Dispatchers.IO) {
        packages.mapNotNull { safePackage(it) }.filter { freezeOne(it) }
    }

    suspend fun unfreeze(packages: List<String>): List<String> = withContext(Dispatchers.IO) {
        packages.mapNotNull { safePackage(it) }.filter { unfreezeOne(it) }
    }

    suspend fun kill(packages: List<String>): Int = withContext(Dispatchers.IO) {
        packages.mapNotNull { safePackage(it) }.count { runCatching { shell("am force-stop $it"); true }.getOrDefault(false) }
    }

    suspend fun stats(): Map<String, Any?> = withContext(Dispatchers.IO) {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val count = manager?.runningAppProcesses?.size ?: 0
        deviceStatsReader.read(count, count)
    }

    suspend fun cleanRam(excludePackage: String? = null): Map<String, Any?> = withContext(Dispatchers.IO) {
        check(status() == "granted") { "Cần quyền Shizuku để dọn RAM." }
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        fun used(): Double {
            val info = ActivityManager.MemoryInfo()
            manager.getMemoryInfo(info)
            return (info.totalMem - info.availMem).toDouble()
        }
        val before = used()
        val targets = runningPackagesUnsafe().filter { it != context.packageName && it != excludePackage }
        shell("am kill-all")
        targets.forEach { runCatching { shell("am force-stop $it") } }
        shell("pm trim-caches 0")
        Thread.sleep(550L)
        val after = used()
        mapOf("succeeded" to true, "beforeUsedBytes" to before, "afterUsedBytes" to after,
            "freedBytes" to (before - after).coerceAtLeast(0.0), "killedApps" to targets.size,
            "trimmedProcesses" to 0, "durationMs" to 550, "method" to "shizuku")
    }

    suspend fun trimCaches(): Boolean = withContext(Dispatchers.IO) {
        runCatching { shell("pm trim-caches 0") }.isSuccess
    }

    private fun freezeOne(packageName: String): Boolean = runCatching {
        shell("cmd appops set $packageName RUN_ANY_IN_BACKGROUND ignore; cmd appops set $packageName RUN_IN_BACKGROUND ignore")
        restrictedPackages.add(packageName)
        disabledPackages = disabledPackages - packageName
        true
    }.getOrDefault(false)

    private fun unfreezeOne(packageName: String): Boolean = runCatching {
        val restore = if (packageName in disabledPackages) "pm enable $packageName; " else ""
        shell("${restore}cmd appops set $packageName RUN_ANY_IN_BACKGROUND allow; cmd appops set $packageName RUN_IN_BACKGROUND allow")
        restrictedPackages.remove(packageName)
        disabledPackages = disabledPackages - packageName
        true
    }.getOrDefault(false)

    private fun runningPackagesUnsafe(): Set<String> = runCatching {
        shell("ps -A -o NAME").lineSequence().map { it.trim() }
            .filter { it.isNotEmpty() && it.contains('.') && !it.startsWith("[") && !it.startsWith("/") && !it.startsWith("-") }
            .map { it.substringBefore(':') }.toSet()
    }.getOrDefault(emptySet())

    private fun safePackage(value: String): String? = value.takeIf { it.matches(Regex("[A-Za-z0-9_.]+")) }

    private fun shell(command: String): String {
        check(status() == "granted") { "Shizuku chưa được cấp quyền." }
        val result = ShizukuShell.run(command)
        check(result.isSuccess) { result.error.ifBlank { result.output }.ifBlank { "Lệnh Shizuku thất bại." } }
        return result.output
    }
}
