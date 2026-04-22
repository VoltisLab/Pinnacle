package com.pinnacle.transfer.pinnacle

import android.app.DownloadManager
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val channelName = "com.pinnacle.transfer/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "publishToDownloads" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val displayName = call.argument<String>("displayName")
                        val mime = call.argument<String>("mime")
                            ?: "application/octet-stream"
                        val folder = sanitizeFolder(
                            call.argument<String>("folder") ?: "Pinnacle",
                        )
                        if (sourcePath == null || displayName == null) {
                            result.error(
                                "ARG",
                                "sourcePath and displayName are required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            val published = publishToDownloads(
                                sourcePath,
                                displayName,
                                mime,
                                folder,
                            )
                            result.success(published)
                        } catch (e: Exception) {
                            result.error("PUBLISH", e.message, null)
                        }
                    }
                    "downloadsLabel" -> {
                        val folder = sanitizeFolder(
                            call.argument<String>("folder") ?: "Pinnacle",
                        )
                        result.success("Downloads / $folder")
                    }
                    "openReceivedLocation" -> {
                        val uriStr = call.argument<String>("uri")
                        val mime = call.argument<String>("mime")
                            ?: "application/octet-stream"
                        try {
                            if (!uriStr.isNullOrEmpty()) {
                                val u = Uri.parse(uriStr)
                                val viewTyped = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(u, mime)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                try {
                                    startActivity(viewTyped)
                                    result.success(true)
                                    return@setMethodCallHandler
                                } catch (_: Exception) {
                                    // Try without strict MIME (some Files builds are picky).
                                }
                                val viewLoose = Intent(Intent.ACTION_VIEW).apply {
                                    setData(u)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                try {
                                    startActivity(viewLoose)
                                    result.success(true)
                                    return@setMethodCallHandler
                                } catch (_: Exception) {
                                }
                            }
                            val dm = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
                            dm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(dm)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Copies [sourcePath] into the user-visible Downloads/<folder> folder.
    /// On API 29+ this uses MediaStore (no permissions required, no
    /// scoped-storage issues). On older Android it writes directly to the
    /// public Downloads directory using the legacy storage API.
    /// Returns a map describing the final location (for UI / logs).
    private fun publishToDownloads(
        sourcePath: String,
        displayName: String,
        mime: String,
        folder: String,
    ): Map<String, String?> {
        val src = File(sourcePath)
        if (!src.exists()) throw IOException("Source file missing: $sourcePath")

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            publishViaMediaStore(src, displayName, mime, folder)
        } else {
            publishLegacy(src, displayName, folder)
        }
    }

    private fun publishViaMediaStore(
        src: File,
        displayName: String,
        mime: String,
        folder: String,
    ): Map<String, String?> {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, displayName)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + "/" + folder,
            )
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri: Uri = resolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values,
        ) ?: throw IOException("MediaStore insert returned null")

        try {
            resolver.openOutputStream(uri, "w").use { out ->
                if (out == null) throw IOException("openOutputStream returned null")
                FileInputStream(src).use { input ->
                    val buf = ByteArray(DEFAULT_COPY_BUFFER)
                    while (true) {
                        val read = input.read(buf)
                        if (read <= 0) break
                        out.write(buf, 0, read)
                    }
                    out.flush()
                }
            }
            val done = ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            resolver.update(uri, done, null, null)
        } catch (e: Exception) {
            try { resolver.delete(uri, null, null) } catch (_: Exception) {}
            throw e
        }
        // Clean up the scratch copy in app cache now that the public copy is
        // committed — leaving both around just wastes disk.
        try { src.delete() } catch (_: Exception) {}

        return mapOf(
            "uri" to uri.toString(),
            "displayLabel" to "Downloads / $folder / $displayName",
            "directoryLabel" to "Downloads / $folder",
        )
    }

    private fun publishLegacy(
        src: File,
        displayName: String,
        folder: String,
    ): Map<String, String?> {
        @Suppress("DEPRECATION")
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        val dir = File(downloads, folder)
        if (!dir.exists() && !dir.mkdirs()) {
            throw IOException("Cannot create ${dir.absolutePath}")
        }
        val target = uniqueFile(dir, displayName)
        FileInputStream(src).use { input ->
            target.outputStream().use { out ->
                input.copyTo(out, DEFAULT_COPY_BUFFER)
            }
        }
        try { src.delete() } catch (_: Exception) {}
        return mapOf(
            "uri" to Uri.fromFile(target).toString(),
            "displayLabel" to "Downloads / $folder / ${target.name}",
            "directoryLabel" to "Downloads / $folder",
        )
    }

    private fun sanitizeFolder(raw: String): String {
        val trimmed = raw.trim()
            .replace(Regex("[\\\\/:*?\"<>|]"), "")
            .replace(Regex("\\s+"), " ")
        return if (trimmed.isBlank()) "Pinnacle" else trimmed
    }

    private fun uniqueFile(dir: File, name: String): File {
        val candidate = File(dir, name)
        if (!candidate.exists()) return candidate
        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val ext = if (dot > 0) name.substring(dot) else ""
        val stamp = System.currentTimeMillis()
        return File(dir, "${stem}_$stamp$ext")
    }

    private companion object {
        const val DEFAULT_COPY_BUFFER = 64 * 1024
    }
}
