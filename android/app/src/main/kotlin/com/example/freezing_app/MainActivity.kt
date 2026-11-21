package com.example.freezing_app

import android.os.Bundle
import android.content.pm.PackageManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleEventEffect
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import rikka.shizuku.Shizuku
import kotlin.coroutines.resume

private val Blue = Color(0xFF2563EB)
private val Page = Color(0xFFF5F7FB)
private val Ink = Color(0xFF15233B)
private val Muted = Color(0xFF64748B)
private val Green = Color(0xFF10B981)
private val Violet = Color(0xFF8B5CF6)

class MainActivity : ComponentActivity() {
    private lateinit var repository: FreezerRepository
    private var permissionContinuation: ((String) -> Unit)? = null
    private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, _ ->
        if (requestCode == REQUEST_CODE) {
            permissionContinuation?.invoke(repository.status())
            permissionContinuation = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        repository = FreezerRepository(applicationContext)
        Shizuku.addRequestPermissionResultListener(permissionListener)
        setContent { FrostGuardApp(repository, ::requestShizukuPermission) }
    }

    private suspend fun requestShizukuPermission(): String {
        when (repository.status()) {
            "granted" -> return "granted"
            "unavailable" -> return "unavailable"
        }
        return suspendCancellableCoroutine { continuation ->
            permissionContinuation = { status -> if (continuation.isActive) continuation.resume(status) }
            continuation.invokeOnCancellation { permissionContinuation = null }
            try { Shizuku.requestPermission(REQUEST_CODE) }
            catch (_: Throwable) { permissionContinuation = null; continuation.resume("unavailable") }
        }
    }

    override fun onDestroy() {
        Shizuku.removeRequestPermissionResultListener(permissionListener)
        super.onDestroy()
    }

    companion object { private const val REQUEST_CODE = 1001 }
}

@Composable
private fun FrostGuardApp(repository: FreezerRepository, requestPermission: suspend () -> String) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    var apps by remember { mutableStateOf<List<ManagedApp>>(emptyList()) }
    var stats by remember { mutableStateOf<Map<String, Any?>>(emptyMap()) }
    var shizuku by remember { mutableStateOf(repository.status()) }
    var loading by remember { mutableStateOf(false) }
    var applying by remember { mutableStateOf(false) }
    var query by remember { mutableStateOf("") }
    var tab by remember { mutableIntStateOf(0) }
    var detail by remember { mutableStateOf<String?>(null) }
    var picker by remember { mutableStateOf(false) }
    var cleaning by remember { mutableStateOf(false) }
    var cleanMessage by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var history by remember { mutableStateOf<List<Float>>(emptyList()) }

    suspend fun refreshApps(force: Boolean = false) {
        if (loading) return
        shizuku = repository.status()
        if (shizuku != "granted") return
        loading = true
        error = null
        try { apps = repository.loadApps(force) }
        catch (e: Exception) { error = e.message ?: "Không tải được danh sách ứng dụng." }
        finally { loading = false }
    }

    LaunchedEffect(Unit) {
        refreshApps(true)
        while (true) {
            runCatching { stats = repository.stats() }
            val cpu = stats.obj("cpu").number("usagePercent").toFloat()
            history = (history + cpu).takeLast(30)
            delay(2_000)
        }
    }
    LifecycleEventEffect(androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
        shizuku = repository.status()
        if (shizuku == "granted") scope.launch { refreshApps() }
    }

    val frozen = apps.filter { it.frozen }
    val running = apps.filter { !it.frozen && it.running }
    val visible = apps.filter { (it.name.contains(query, true) || it.packageName.contains(query, true)) && (tab == 0 && !it.system || tab == 1 && it.system) }
    val userFrozen = apps.filter { it.frozen && !it.system }
    val systemFrozen = apps.filter { it.frozen && it.system }

    MaterialTheme(colorScheme = lightColorScheme(primary = Blue, background = Page, surface = Color.White, onSurface = Ink)) {
        if (detail != null) {
            HardwareDetails(detail!!, stats, history) { detail = null }
            return@MaterialTheme
        }
        Scaffold(containerColor = Page, snackbarHost = { SnackbarHost(snackbarHostState) }, floatingActionButton = {
            ExtendedFloatingActionButton(onClick = { picker = true }, containerColor = Blue, contentColor = Color.White,
                icon = { Icon(Icons.Rounded.PowerSettingsNew, null) }, text = { Text("Kill app", fontWeight = FontWeight.Bold) })
        }) { padding ->
            LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(bottom = 96.dp)) {
                item {
                    Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 16.dp, top = 12.dp, bottom = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background(Blue), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.AcUnit, null, tint = Color.White) }
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            Text("FrostGuard", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                            Text("SMART APP FREEZER  ·  PRO", style = MaterialTheme.typography.labelSmall, color = Muted)
                        }
                        IconButton(onClick = { scope.launch { refreshApps(true) } }) { Icon(Icons.Rounded.Refresh, "Làm mới", tint = Blue) }
                    }
                }
                item { ShizukuCard(shizuku, onConnect = {
                    scope.launch {
                        shizuku = requestPermission()
                        if (shizuku == "granted") refreshApps(true)
                    }
                }) }
                item { StatsCard(stats, onDetail = { detail = it }, onClean = {
                    scope.launch {
                        cleaning = true
                        cleanMessage = null
                        val result = runCatching { repository.cleanRam(context.packageName) }
                        cleanMessage = result.fold(
                            { "Đã hoàn tất · giải phóng khoảng ${formatBytes(it.number("freedBytes"))}" },
                            { it.message ?: "Không thể dọn RAM. Hãy kiểm tra quyền Shizuku." },
                        )
                        cleaning = false
                        runCatching { stats = repository.stats() }
                    }
                }) }
                item {
                    Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 20.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Danh sách ứng dụng", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                        if (apps.isNotEmpty()) SmallPill("${apps.size} ứng dụng")
                    }
                }
                if (error != null) item { Text(error!!, Modifier.padding(horizontal = 20.dp, vertical = 8.dp), color = MaterialTheme.colorScheme.error) }
                if (shizuku != "granted") {
                    item { EmptyPanel(error ?: if (shizuku == "denied") "Cần cấp quyền Shizuku để điều khiển ứng dụng." else "Hãy cài đặt và khởi động Shizuku trước.", onRetry = { scope.launch { refreshApps(true) } }) }
                } else {
                    item {
                        OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                            placeholder = { Text("Tìm ứng dụng hoặc package") }, leadingIcon = { Icon(Icons.Rounded.Search, null) }, singleLine = true,
                            shape = RoundedCornerShape(16.dp))
                    }
                    item {
                        TabRow(tab, Modifier.padding(horizontal = 16.dp), containerColor = Color.Transparent) {
                            Tab(tab == 0, { tab = 0 }, text = { Text("Đã cài đặt (${apps.count { !it.system }})") })
                            Tab(tab == 1, { tab = 1 }, text = { Text("Hệ thống (${apps.count { it.system }})") })
                        }
                    }
                    item {
                        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            OutlinedButton(enabled = !applying && visible.any { !it.frozen }, modifier = Modifier.weight(1f), onClick = {
                                scope.launch { applying = true; val result = repository.freeze(visible.filter { !it.frozen }.map { it.packageName }); repository.kill(result); refreshApps(); applying = false; snackbarHostState.showSnackbar("Đã đóng băng ${result.size} ứng dụng") }
                            }) { Icon(Icons.Rounded.AcUnit, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text("Đóng băng tất cả") }
                            OutlinedButton(enabled = !applying && visible.any { it.frozen }, modifier = Modifier.weight(1f), onClick = {
                                scope.launch { applying = true; val result = repository.unfreeze(visible.filter { it.frozen }.map { it.packageName }); refreshApps(); applying = false; snackbarHostState.showSnackbar("Đã rã đông ${result.size} ứng dụng") }
                            }) { Icon(Icons.Rounded.WbSunny, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text("Rã đông tất cả") }
                        }
                    }
                    if (loading && apps.isEmpty()) item { Box(Modifier.fillMaxWidth().padding(36.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
                    else if (visible.isEmpty()) item { EmptyPanel("Không có ứng dụng trong nhóm này", onRetry = { scope.launch { refreshApps(true) } }) }
                    else items(visible, key = { it.packageName }) { app ->
                AppRow(app, Modifier.padding(horizontal = 16.dp, vertical = 4.dp), enabled = !applying, onToggle = {
                            scope.launch {
                                applying = true
                                val success = repository.toggle(app)
                                refreshApps()
                                applying = false
                                if (!success) snackbarHostState.showSnackbar("Không thể ${if (app.frozen) "rã đông" else "đóng băng"} ${app.name}")
                            }
                        })
                    }
                    if (frozen.isNotEmpty() || running.isNotEmpty()) item {
                        Column(Modifier.padding(horizontal = 16.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Tổng quan", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                SummaryCard("Đã đóng băng", frozen.size.toString(), Violet, Modifier.weight(1f))
                                SummaryCard("Đang chạy", running.size.toString(), Green, Modifier.weight(1f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                SummaryCard("RAM ước tính tiết kiệm", formatBytes(frozen.size * 380.0 * 1024 * 1024), Blue, Modifier.weight(1f))
                                SummaryCard("Điện chờ ước tính", "${frozen.size * 32} mA", Color(0xFFF59E0B), Modifier.weight(1f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                OutlinedButton(enabled = !applying && frozen.isNotEmpty(), modifier = Modifier.weight(1f), onClick = {
                                    scope.launch { applying = true; val result = repository.unfreeze(userFrozen.map { it.packageName } + systemFrozen.map { it.packageName }); refreshApps(); applying = false; snackbarHostState.showSnackbar("Đã rã đông ${result.size} ứng dụng") }
                                }) { Text("Rã đông tất cả") }
                                OutlinedButton(enabled = !applying && running.isNotEmpty(), modifier = Modifier.weight(1f), onClick = {
                                    scope.launch { applying = true; val count = repository.kill(running.map { it.packageName }); refreshApps(); applying = false; snackbarHostState.showSnackbar("Đã dừng $count ứng dụng") }
                                }) { Text("Dừng ứng dụng chạy") }
                            }
                        }
                    }
                }
            }
        }

        if (picker) {
            KillAppPicker(
                apps = apps,
                applying = applying,
                onClose = { picker = false },
                onKill = { app ->
                    scope.launch {
                        applying = true
                        val count = runCatching { repository.kill(listOf(app.packageName)) }.getOrDefault(0)
                        refreshApps()
                        applying = false
                        snackbarHostState.showSnackbar(if (count > 0) "Đã kill ${app.name}" else "Không thể kill ${app.name}")
                    }
                },
                onKillAll = {
                    val targetPackages = apps.map { it.packageName }
                    val total = targetPackages.size
                    scope.launch {
                        applying = true
                        val count = runCatching { repository.kill(targetPackages) }.getOrDefault(0)
                        refreshApps()
                        applying = false
                        picker = false
                        snackbarHostState.showSnackbar("Đã kill $count/$total ứng dụng")
                    }
                },
            )
        }
        if (cleaning || cleanMessage != null) AlertDialog(
            onDismissRequest = { if (!cleaning) cleanMessage = null },
            icon = { Icon(if (cleaning) Icons.Rounded.Speed else Icons.Rounded.CheckCircle, null, tint = if (cleaning) Violet else Green, modifier = Modifier.size(36.dp)) },
            title = { Text(if (cleaning) "Đang tăng tốc RAM" else "Tăng tốc RAM") },
            text = { if (cleaning) Row(verticalAlignment = Alignment.CenterVertically) { CircularProgressIndicator(Modifier.size(22.dp)); Spacer(Modifier.width(14.dp)); Text("Đang giải phóng bộ nhớ nền…") } else Text(cleanMessage.orEmpty()) },
            confirmButton = { if (!cleaning) TextButton(onClick = { cleanMessage = null }) { Text("Đóng") } },
        )
    }
}

@Composable
private fun ShizukuCard(status: String, onConnect: () -> Unit) {
    val granted = status == "granted"
    val denied = status == "denied"
    val color = if (granted) Green else if (denied) Color(0xFFEF4444) else Color(0xFFF59E0B)
    Surface(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 5.dp), shape = RoundedCornerShape(20.dp), color = Color.White, shadowElevation = 2.dp, border = androidx.compose.foundation.BorderStroke(1.dp, color.copy(alpha = .22f))) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(if (granted) Icons.Rounded.VerifiedUser else Icons.Rounded.PowerSettingsNew, null, tint = color, modifier = Modifier.size(28.dp))
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(if (granted) "Đã kết nối Shizuku" else if (denied) "Cần cấp quyền Shizuku" else "Shizuku chưa hoạt động", fontWeight = FontWeight.Bold)
                Text(if (granted) "Quyền điều khiển ứng dụng đã sẵn sàng." else if (denied) "Cấp quyền truy cập trong bảng thông báo Shizuku." else "Khởi chạy dịch vụ Shizuku rồi kết nối.", color = Muted, style = MaterialTheme.typography.bodySmall)
            }
            if (!granted) TextButton(onClick = onConnect) { Text(if (denied) "Cấp quyền" else "Kết nối") }
        }
    }
}

@Composable
private fun StatsCard(stats: Map<String, Any?>, onDetail: (String) -> Unit, onClean: () -> Unit) {
    val cpu = stats.obj("cpu"); val ram = stats.obj("ram"); val bat = stats.obj("battery"); val gpu = stats.obj("gpu"); val net = stats.obj("network")
    Surface(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 5.dp), shape = RoundedCornerShape(20.dp), color = Color.White, shadowElevation = 2.dp) {
        Column(Modifier.padding(14.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Metric("CPU", "${cpu.number("usagePercent").format1()}%", Icons.Rounded.Memory, Blue, Modifier.weight(1f)) { onDetail("CPU") }
                Metric("RAM", "${ram.number("usedBytes").let { if (ram.number("totalBytes") > 0) (it * 100 / ram.number("totalBytes")).toInt() else 0 }}%", Icons.Rounded.Dns, Violet, Modifier.weight(1f), onClean)
                Metric("Pin", "${bat.number("levelPercent").toInt()}%", Icons.Rounded.BatteryChargingFull, Green, Modifier.weight(1f)) { onDetail("Pin") }
                Metric("Dung lượng", bat.number("capacityMah").let { if (it > 0) "${it.toInt()} mAh" else "N/A" }, Icons.Rounded.Bolt, Color(0xFFF59E0B), Modifier.weight(1f)) { onDetail("Pin") }
            }
            HorizontalDivider(Modifier.padding(vertical = 12.dp), color = Color(0xFFE9EEF5))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Metric("GPU", if (gpu.number("usagePercent") < 0) "N/A" else "${gpu.number("usagePercent").format1()}%", Icons.Rounded.DeveloperBoard, Color(0xFF14B8A6), Modifier.weight(1f)) { onDetail("GPU") }
                Metric("Nhiệt độ", celsius(gpu["temperatureCelsius"] ?: cpu["temperatureCelsius"]), Icons.Rounded.DeviceThermostat, Color(0xFFEF4444), Modifier.weight(1f)) { onDetail("Nhiệt độ") }
                Metric("Mạng", "${net.number("downloadMbps").format1()} ↓  ${net.number("uploadMbps").format1()} ↑", Icons.Rounded.SwapVert, Color(0xFF0EA5E9), Modifier.weight(1f)) {}
            }
        }
    }
}

@Composable
private fun Metric(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(modifier.clip(RoundedCornerShape(12.dp)).clickable(onClick = onClick).padding(vertical = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, tint = color, modifier = Modifier.size(20.dp))
        Text(value, maxLines = 1, overflow = TextOverflow.Ellipsis, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge)
        Text(label, maxLines = 1, color = Muted, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun AppRow(app: ManagedApp, modifier: Modifier = Modifier, enabled: Boolean = true, onToggle: () -> Unit) {
    val context = LocalContext.current
    val icon = remember(app.packageName) { runCatching { context.packageManager.getApplicationIcon(app.packageName) }.getOrNull() }
    val iconBitmap = remember(app.packageName, icon) { icon?.toBitmapCompat()?.asImageBitmap() }
    Surface(modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), color = Color.White) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            if (iconBitmap != null) androidx.compose.foundation.Image(iconBitmap, null, Modifier.size(42.dp).clip(RoundedCornerShape(12.dp)))
            else Icon(Icons.Rounded.Android, null, Modifier.size(42.dp).padding(8.dp), tint = Blue)
            Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                Text(app.name, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(app.packageName, color = Muted, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Switch(checked = app.frozen, onCheckedChange = { onToggle() }, enabled = enabled)
        }
    }
}

@Composable
private fun KillAppPicker(
    apps: List<ManagedApp>,
    applying: Boolean,
    onClose: () -> Unit,
    onKill: (ManagedApp) -> Unit,
    onKillAll: () -> Unit,
) {
    var tab by remember { mutableIntStateOf(0) }
    var query by remember { mutableStateOf("") }
    var confirmKillAll by remember { mutableStateOf(false) }
    val visibleApps = apps.filter {
        it.system == (tab == 1) &&
            (it.name.contains(query, ignoreCase = true) || it.packageName.contains(query, ignoreCase = true))
    }
    AlertDialog(
        onDismissRequest = { if (!applying) onClose() },
        title = { Text("Kill app") },
        text = {
            Column(Modifier.fillMaxWidth().heightIn(max = 560.dp)) {
                Text("Force-stop ứng dụng trong lần này. Ứng dụng có thể tự chạy lại theo cơ chế của Android.", color = Muted, style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(10.dp))
                TabRow(tab) {
                    Tab(tab == 0, { tab = 0 }, text = { Text("Đã cài đặt (${apps.count { !it.system }})") })
                    Tab(tab == 1, { tab = 1 }, text = { Text("Hệ thống (${apps.count { it.system }})") })
                }
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    placeholder = { Text("Tìm ứng dụng") },
                    leadingIcon = { Icon(Icons.Rounded.Search, null) },
                    singleLine = true,
                    shape = RoundedCornerShape(14.dp),
                )
                OutlinedButton(
                    onClick = { confirmKillAll = true },
                    enabled = !applying && apps.isNotEmpty(),
                    modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                ) {
                    Icon(Icons.Rounded.PowerSettingsNew, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Kill tất cả ứng dụng (${apps.size})")
                }
                LazyColumn(Modifier.weight(1f, fill = false).heightIn(min = 140.dp, max = 320.dp)) {
                    items(visibleApps, key = { it.packageName }) { app ->
                        KillAppRow(app = app, enabled = !applying, onKill = { onKill(app) })
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onClose, enabled = !applying) { Text("Đóng") } },
    )
    if (confirmKillAll) AlertDialog(
        onDismissRequest = { confirmKillAll = false },
        title = { Text("Kill tất cả ứng dụng?") },
        text = { Text("FrostGuard sẽ force-stop ${apps.size} ứng dụng đã cài, bao gồm cả ứng dụng hệ thống. Một số chức năng của máy có thể tạm thời bị ảnh hưởng.") },
        confirmButton = {
            TextButton(onClick = { confirmKillAll = false; onKillAll() }) { Text("Kill tất cả", color = MaterialTheme.colorScheme.error) }
        },
        dismissButton = { TextButton(onClick = { confirmKillAll = false }) { Text("Hủy") } },
    )
}

@Composable
private fun KillAppRow(app: ManagedApp, enabled: Boolean, onKill: () -> Unit) {
    val context = LocalContext.current
    val icon = remember(app.packageName) { runCatching { context.packageManager.getApplicationIcon(app.packageName) }.getOrNull() }
    val iconBitmap = remember(app.packageName, icon) { icon?.toBitmapCompat()?.asImageBitmap() }
    Row(
        Modifier.fillMaxWidth().padding(vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (iconBitmap != null) androidx.compose.foundation.Image(iconBitmap, app.name, Modifier.size(42.dp).clip(RoundedCornerShape(11.dp)))
        else Icon(Icons.Rounded.Android, app.name, Modifier.size(42.dp).padding(8.dp), tint = Blue)
        Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
            Text(app.name, fontWeight = FontWeight.SemiBold)
            Text(app.packageName, color = Muted, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        TextButton(onClick = onKill, enabled = enabled) {
            Icon(Icons.Rounded.PowerSettingsNew, null, Modifier.size(17.dp), tint = MaterialTheme.colorScheme.error)
            Spacer(Modifier.width(4.dp))
            Text("Kill", color = MaterialTheme.colorScheme.error)
        }
    }
    HorizontalDivider(color = Color(0xFFE9EEF5))
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun HardwareDetails(section: String, stats: Map<String, Any?>, history: List<Float>, onBack: () -> Unit) {
    val key = when (section) { "CPU" -> "cpu"; "GPU" -> "gpu"; "Pin" -> "battery"; "Nhiệt độ" -> "cpu"; else -> "cpu" }
    val data = stats.obj(key)
    val heroValue = when (section) {
        "Pin" -> "${data.number("levelPercent").toInt()}%"
        "Nhiệt độ" -> celsius(data["temperatureCelsius"])
        "GPU" -> if (data.number("usagePercent") < 0) "N/A" else "${data.number("usagePercent").format1()}%"
        else -> "${data.number("usagePercent").format1()}%"
    }
    Scaffold(topBar = { TopAppBar(title = { Text("Chi tiết $section") }, navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.Rounded.ArrowBack, "Quay lại") } }) }) { padding ->
        LazyColumn(Modifier.fillMaxSize().background(Page).padding(padding), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item {
                Surface(shape = RoundedCornerShape(20.dp), color = Color.White) {
                    Row(Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) { Text(data.string("model").ifBlank { data.string("name").ifBlank { "${section} thiết bị" } }, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.titleMedium); Text("Mức sử dụng hiện tại", color = Muted) }
                        Text(heroValue, color = Blue, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    }
                }
            }
            if (section == "CPU") item { HistoryChart(history, section) }
            val rows = when (section) {
                "CPU" -> {
                    val cores = data.number("coreCount")
                    val load = if (cores > 0) (data.number("loadAverage") / cores * 100).coerceIn(0.0, 100.0) else 0.0
                    val temp = (data["temperatureCelsius"] as? Number)?.toDouble() ?: 0.0
                    listOf("SoC / model" to data.string("model"), "Kiến trúc" to data.string("architecture"), "Số nhân logic" to "${cores.toInt()} nhân", "Xung hiện tại" to mhz(data.number("currentFrequencyMhz")), "Xung tối đa" to mhz(data.number("maxFrequencyMhz")), "Nhiệt độ" to celsius(data["temperatureCelsius"]), "Load average" to data.number("loadAverage").format1(), "Load theo nhân" to "${load.format1()}%", "Trạng thái nhiệt" to if (temp >= 70) "Nóng" else if (temp >= 55) "Ấm" else "Bình thường", "Tiến trình" to data.number("processCount").toInt().toString())
                }
                "GPU" -> listOf("GPU model" to data.string("name"), "Mức sử dụng" to if (data.number("usagePercent") < 0) "Không thể lấy trên thiết bị này" else "${data.number("usagePercent").format1()}%", "Xung hiện tại" to mhz(data.number("currentFrequencyMhz")), "Nhiệt độ" to celsius(data["temperatureCelsius"]))
                "Pin" -> {
                    val battery = stats.obj("battery")
                    val reference = if (battery.number("designCapacityMah") > 0) battery.number("designCapacityMah") else battery.number("referenceCapacityMah")
                    val actual = if (battery.number("fullChargeCapacityMah") > 0) battery.number("fullChargeCapacityMah") else battery.number("measuredCapacityMah")
                    val health = if (reference > 0 && actual > 0) (actual / reference * 100).coerceIn(0.0, 100.0) else null
                    val charging = battery["isCharging"] == true
                    val plugged = battery["isPlugged"] == true
                    listOf(
                        "Mức pin hiện tại" to "${battery.number("levelPercent").toInt()}%",
                        "Trạng thái" to if (charging) "Đang sạc" else if (plugged) "Đã cắm sạc" else "Đang hao",
                        "Nguồn sạc" to battery.string("plugType"),
                        "Sức khỏe hệ thống" to battery.string("health"),
                        "Độ chai ước tính" to (health?.let { "${(100 - it).format1()}%" } ?: "Cần đo khi pin trên 80%"),
                        "Sức khỏe pin ước tính" to (health?.let { "${it.format1()}%" } ?: "Cần đo khi pin trên 80%"),
                        "Dung lượng thiết kế" to mah(battery.number("designCapacityMah")),
                        "Dung lượng thực tế" to mah(actual),
                        "Mốc tham chiếu" to if (battery.number("referenceCapacityMah") > 0) mah(battery.number("referenceCapacityMah")) else "Ghi nhận khi pin trên 80%",
                        "Bộ đếm điện lượng" to mah(battery.number("chargeCounterMah")),
                        "Điện áp" to "${battery.number("voltageMilliVolts").toInt()} mV",
                        "Dòng điện" to "${battery.number("currentMilliAmps").toInt()} mA",
                        "Nhiệt độ" to celsius(battery["temperatureCelsius"]),
                        "Thời gian ước tính còn lại" to (battery["estimatedRemainingMinutes"] as? Number)?.toInt()?.let { "$it phút" }.orEmpty().ifBlank { "N/A" },
                        "Công nghệ" to battery.string("technology"),
                    )
                }
                else -> {
                    val bat = stats.obj("battery")
                    val cpuTemp = (stats.obj("cpu")["temperatureCelsius"] as? Number)?.toDouble() ?: 0.0
                    val batteryTemp = bat.number("temperatureCelsius")
                    listOf("CPU / SoC" to celsius(stats.obj("cpu")["temperatureCelsius"]), "GPU" to celsius(stats.obj("gpu")["temperatureCelsius"]), "Pin" to celsius(bat["temperatureCelsius"]), "Trạng thái CPU" to if (cpuTemp >= 70) "Nóng" else if (cpuTemp >= 55) "Ấm" else "Bình thường", "Trạng thái pin" to if (batteryTemp >= 45) "Nóng" else if (batteryTemp >= 40) "Ấm" else "Bình thường")
                }
            }
            item { DetailGroup(section, rows) }
        }
    }
}

@Composable
private fun DetailGroup(title: String, rows: List<Pair<String, String>>) {
    Surface(shape = RoundedCornerShape(20.dp), color = Color.White) {
        Column(Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            rows.forEach { (label, value) ->
                Row(Modifier.fillMaxWidth().padding(vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(label, Modifier.weight(1f), color = Muted)
                    Text(value.ifBlank { "N/A" }, fontWeight = FontWeight.SemiBold)
                }
                if (label != rows.lastOrNull()?.first) HorizontalDivider(color = Color(0xFFE9EEF5))
            }
        }
    }
}

@Composable
private fun HistoryChart(values: List<Float>, title: String) {
    Surface(shape = RoundedCornerShape(20.dp), color = Color.White) {
        Column(Modifier.fillMaxWidth().padding(16.dp)) {
            Text("Lịch sử $title", fontWeight = FontWeight.Bold)
            Canvas(Modifier.fillMaxWidth().height(110.dp).padding(top = 10.dp)) {
                if (values.size > 1) {
                    val step = size.width / (values.size - 1)
                    val path = androidx.compose.ui.graphics.Path()
                    values.forEachIndexed { index, value ->
                        val y = size.height * (1f - value.coerceIn(0f, 100f) / 100f)
                        if (index == 0) path.moveTo(0f, y) else path.lineTo(index * step, y)
                    }
                    drawPath(path, Blue, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
                }
            }
        }
    }
}

@Composable
private fun SummaryCard(title: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Surface(modifier, shape = RoundedCornerShape(16.dp), color = Color.White) { Column(Modifier.padding(14.dp)) { Text(value, color = color, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.headlineSmall); Text(title, color = Muted, style = MaterialTheme.typography.bodySmall) } }
}

@Composable
private fun SmallPill(text: String) { Surface(shape = CircleShape, color = Blue.copy(alpha = .1f)) { Text(text, Modifier.padding(horizontal = 10.dp, vertical = 5.dp), color = Blue, style = MaterialTheme.typography.labelSmall) } }

@Composable
private fun EmptyPanel(message: String, onRetry: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(30.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.Rounded.AcUnit, null, Modifier.size(46.dp), tint = Blue.copy(alpha = .6f))
        Spacer(Modifier.height(12.dp)); Text(message, color = Muted); Spacer(Modifier.height(12.dp))
        OutlinedButton(onClick = onRetry) { Icon(Icons.Rounded.Refresh, null, Modifier.size(18.dp)); Spacer(Modifier.width(6.dp)); Text("Tải lại") }
    }
}

private fun Map<String, Any?>.obj(key: String): Map<String, Any?> = (this[key] as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value } ?: emptyMap()
private fun Map<String, Any?>.number(key: String): Double = (this[key] as? Number)?.toDouble() ?: 0.0
private fun Map<String, Any?>.string(key: String): String = this[key]?.toString().orEmpty()
private fun Double.format1(): String = String.format(java.util.Locale.getDefault(), "%.1f", this)
private fun celsius(value: Any?): String = (value as? Number)?.toDouble()?.takeIf { it > 0 }?.let { "${it.format1()} °C" } ?: "Không thể lấy"
private fun mhz(value: Double): String = if (value > 0) "${value.toInt()} MHz" else "Không thể lấy"
private fun mah(value: Double): String = if (value > 0) "${value.toInt()} mAh" else "Không thể lấy trên thiết bị này"
private fun formatBytes(value: Double): String = if (value >= 1024 * 1024 * 1024) "${(value / (1024 * 1024 * 1024)).format1()} GB" else "${(value / (1024 * 1024)).format1()} MB"

private fun android.graphics.drawable.Drawable.toBitmapCompat(): android.graphics.Bitmap {
    val bitmap = android.graphics.Bitmap.createBitmap(96, 96, android.graphics.Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    setBounds(0, 0, canvas.width, canvas.height)
    draw(canvas)
    return bitmap
}
