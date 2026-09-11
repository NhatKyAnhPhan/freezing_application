package com.example.freezing_app

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
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
	private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, _ ->
		if (requestCode == REQUEST_CODE) {
			permissionResult?.success(shizukuStatus())
			permissionResult = null
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		Shizuku.addRequestPermissionResultListener(permissionListener)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"getShizukuStatus" -> result.success(shizukuStatus())
				"requestShizukuPermission" -> requestShizukuPermission(result)
				"getInstalledApps" -> getInstalledApps(result)
				"setFrozen" -> {
					val packageName = call.argument<String>("packageName")
					val frozen = call.argument<Boolean>("frozen") ?: false
					if (packageName == null) {
						result.error("INVALID_ARGUMENT", "packageName is required", null)
					} else {
						setFrozen(packageName, frozen, result)
					}
				}
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
					.filter { it.packageName != packageName && isUserFacingApp(it) }
					.sortedBy { it.loadLabel(packageManager).toString().lowercase() }
					.map {
						mapOf(
							"name" to it.loadLabel(packageManager).toString(),
							"packageName" to it.packageName,
							"isFrozen" to disabledPackages.contains(it.packageName),
						)
					}
				runOnUiThread { result.success(apps) }
			} catch (error: Exception) {
				runOnUiThread { result.error("SHIZUKU_COMMAND", error.message, null) }
			}
		}.start()
	}

	private fun setFrozen(packageName: String, frozen: Boolean, result: MethodChannel.Result) {
		if (shizukuStatus() != "granted") {
			result.error("SHIZUKU_PERMISSION", "Shizuku permission is required", null)
			return
		}
		Thread {
			try {
				val command = if (frozen) "pm disable-user --user 0 $packageName" else "pm enable $packageName"
				runShell(command)
				runOnUiThread { result.success(true) }
			} catch (error: Exception) {
				runOnUiThread { result.error("SHIZUKU_COMMAND", error.message, null) }
			}
		}.start()
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
