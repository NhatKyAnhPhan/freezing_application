package com.example.freezing_app
import kotlin.collections.*

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku

/**
 * Thin wrapper around the Shizuku shell bridge.
 *
 * Every call is guarded: Shizuku can disappear at any moment (permission
 * revoked, manager service killed) and we must degrade to a normal failure
 * instead of crashing the app.
 */
object ShizukuShell {
	private const val COMMAND_TIMEOUT_MS = 12000L

	fun isAvailable(): Boolean = try {
		Shizuku.pingBinder()
	} catch (error: Throwable) {
		false
	}

	fun isGranted(): Boolean {
		if (!isAvailable()) return false
		return try {
			Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
		} catch (error: Throwable) {
			false
		}
	}

	/** Result of one shell invocation. */
	data class ShellResult(val output: String, val error: String, val exitCode: Int) {
		val isSuccess: Boolean get() = exitCode == 0
	}

	/**
	 * Runs [command] through `sh -c` as the Shizuku user.
	 *
	 * Never throws: a non-zero exit code is reported inside [ShellResult] so the
	 * caller can decide whether the failure is fatal.
	 */
	fun run(command: String): ShellResult {
		if (!isGranted()) {
			return ShellResult("", "Shizuku permission is required", -1)
		}
		return try {
			val process = Shizuku.newProcess(arrayOf("sh", "-c", command), null, null)
			val output = process.inputStream.bufferedReader().use { it.readText() }
			val error = process.errorStream.bufferedReader().use { it.readText() }
			ShellResult(output, error, waitFor(process))
		} catch (error: Throwable) {
			ShellResult("", error.message ?: "Unknown shell failure", -2)
		}
	}

	/** Runs [commands] in a single shell round trip. */
	fun runAll(commands: List<String>): ShellResult {
		if (commands.isEmpty()) return ShellResult("", "", 0)
		return run(commands.joinToString(separator = " ; "))
	}

	/**
	 * Runs [command] and returns the packages it listed, dropping the
	 * `package:` prefix used by `pm list packages`.
	 */
	fun packages(command: String): Set<String> {
		val result = run(command)
		if (!result.isSuccess) return emptySet()
		val packages = HashSet<String>()
		for (line in result.output.lineSequence()) {
			val trimmed = line.trim()
			if (trimmed.isEmpty()) continue
			val name = trimmed.removePrefix("package:").trim()
			if (name.isNotEmpty()) packages.add(name)
		}
		return packages
	}

	/** Package names parsed from the process table, ignoring kernel threads. */
	fun runningPackages(): Set<String> {
		val result = run("ps -A -o NAME")
		if (!result.isSuccess) return emptySet()
		val packages = HashSet<String>()
		for (line in result.output.lineSequence()) {
			val name = line.trim()
			// Only real packages contain a dot and are not prefixed with '['.
			if (name.isEmpty() || name.startsWith("[") || !name.contains('.')) continue
			if (name.startsWith("/") || name.startsWith("-")) continue
			packages.add(if (name.contains(':')) name.substringBefore(':') else name)
		}
		return packages
	}

	/** Counts the numeric entries in `/proc`, i.e. live processes. */
	fun processCount(): Int {
		val result = run("ls /proc")
		if (!result.isSuccess) return 0
		var count = 0
		for (line in result.output.lineSequence()) {
			val name = line.trim()
			if (name.isEmpty()) continue
			if (name[0].isDigit()) count++
		}
		return count
	}

	private fun waitFor(process: Process): Int {
		val deadline = System.currentTimeMillis() + COMMAND_TIMEOUT_MS
		while (System.currentTimeMillis() < deadline) {
			try {
				return process.exitValue()
			} catch (error: IllegalThreadStateException) {
				Thread.sleep(12L)
			}
		}
		return try {
			process.destroy()
			process.exitValue()
		} catch (error: Throwable) {
			-3
		}
	}
}
