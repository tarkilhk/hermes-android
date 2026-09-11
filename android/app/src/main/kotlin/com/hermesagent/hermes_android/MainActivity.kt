package com.hermesagent.hermes_android

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val shareChannelName = "com.hermesagent.hermes_android/share"
    private val launchChannelName = "com.hermesagent.hermes_android/launch"
    private val quickChatAction = "com.hermesagent.hermes_android.action.QUICK_CHAT"
    private val intakePreferencesName = "pending_share_intake"
    private val intakeQueueKey = "queue"
    private val maxSharedItems = 10
    private val maxSharedBytes = 64L * 1024L * 1024L
    private val maxPendingRecords = 10
    private val maxPendingBytes = 128L * 1024L * 1024L
    private val maxSharedTextChars = 256 * 1024
    private var shareChannel: MethodChannel? = null
    private var launchChannel: MethodChannel? = null
    private var initialShareIntent: Intent? = null
    private var initialLaunchAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        initialShareIntent = intent.takeIf(::isShareIntent)
        initialLaunchAction = launchActionFor(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingShare" -> {
                        val pendingIntent = initialShareIntent
                        initialShareIntent = null
                        intakeExecutor.execute {
                            try {
                                if (pendingIntent != null) importShareIntent(pendingIntent)
                                postResult(result, oldestPendingPayload())
                            } catch (error: Exception) {
                                postShareError(safeImportMessage(error))
                                postResult(result, oldestPendingPayloadSafely())
                            } finally {
                                if (pendingIntent != null) clearConsumedShareIntent(pendingIntent)
                            }
                        }
                    }
                    "acknowledgeShare" -> {
                        val id = (call.argument<String>("id") ?: "").trim()
                        intakeExecutor.execute {
                            try {
                                postResult(result, acknowledgeShare(id))
                            } catch (_: Exception) {
                                postError(result, "share_ack_failed", genericAcknowledgeError)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
        launchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, launchChannelName).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLaunchAction" -> {
                        val pending = initialLaunchAction
                        initialLaunchAction = null
                        result.success(pending)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchActionFor(intent)?.let { action ->
            launchChannel?.invokeMethod("launchAction", action)
            return
        }
        if (!isShareIntent(intent)) return
        intakeExecutor.execute {
            try {
                importShareIntent(intent)
                postSharePayload(oldestPendingPayload())
            } catch (error: Exception) {
                postShareError(safeImportMessage(error))
            } finally {
                clearConsumedShareIntent(intent)
            }
        }
    }

    private fun launchActionFor(intent: Intent?): String? =
        if (intent?.action == quickChatAction) "quickChat" else null

    private fun isShareIntent(intent: Intent?): Boolean =
        intent?.action == Intent.ACTION_SEND || intent?.action == Intent.ACTION_SEND_MULTIPLE

    private fun importShareIntent(intent: Intent) {
        val queue = readQueue()
        pruneOrphanedIntake(queue)
        val fingerprint = shareFingerprint(intent)
        val alreadyPending = (0 until queue.length()).any {
            queue.getJSONObject(it).optString("fingerprint") == fingerprint
        }
        if (alreadyPending) return
        if (queue.length() >= maxPendingRecords) {
            throw ShareImportException(queueFullError)
        }

        val text = extractSharedText(intent)
        if ((text?.length ?: 0) > maxSharedTextChars) {
            throw ShareImportException(textTooLargeError)
        }
        val uris = sharedUris(intent)
        if (uris.size > maxSharedItems) {
            throw ShareImportException(tooManyFilesError)
        }
        if (text == null && uris.isEmpty()) {
            throw ShareImportException(genericImportError)
        }

        val id = UUID.randomUUID().toString()
        val directory = File(intakeDirectory(), id)
        val files = JSONArray()
        var copiedBytes = 0L
        try {
            uris.forEachIndexed { index, uri ->
                val remainingIncoming = maxSharedBytes - copiedBytes
                val remainingQueue = maxPendingBytes - queueBytes(queue) - copiedBytes
                if (remainingIncoming <= 0L) throw ShareImportException(incomingTooLargeError)
                if (remainingQueue <= 0L) throw ShareImportException(queueFullError)
                val file = copySharedUri(
                    uri = uri,
                    index = index,
                    fallbackType = intent.type,
                    directory = directory,
                    byteLimit = minOf(remainingIncoming, remainingQueue),
                    queueIsLimiting = remainingQueue < remainingIncoming,
                )
                files.put(file)
                copiedBytes += file.getLong("byteLength")
            }
            val record = JSONObject()
                .put("id", id)
                .put("fingerprint", fingerprint)
                .put("text", text ?: JSONObject.NULL)
                .put("files", files)
            queue.put(record)
            if (!writeQueue(queue)) throw ShareImportException(genericImportError)
        } catch (error: ShareImportException) {
            directory.deleteRecursively()
            throw error
        } catch (_: Exception) {
            directory.deleteRecursively()
            throw ShareImportException(genericImportError)
        }
    }

    private fun acknowledgeShare(id: String): Map<String, Any?>? {
        if (id.isEmpty()) throw ShareImportException(genericImportError)
        val queue = readQueue()
        val next = JSONArray()
        var removed = false
        for (index in 0 until queue.length()) {
            val record = queue.getJSONObject(index)
            if (!removed && record.getString("id") == id) {
                removed = true
            } else {
                next.put(record)
            }
        }
        if (removed) {
            if (!writeQueue(next)) throw ShareImportException(genericImportError)
            deleteIntakeDirectory(id)
        }
        pruneOrphanedIntake(next)
        return oldestPayload(next)
    }

    private fun copySharedUri(
        uri: Uri,
        index: Int,
        fallbackType: String?,
        directory: File,
        byteLimit: Long,
        queueIsLimiting: Boolean,
    ): JSONObject {
        val mediaType = contentResolver.getType(uri)?.trim().orEmpty()
            .ifEmpty { fallbackType?.trim().orEmpty() }
            .ifEmpty { "application/octet-stream" }
        val displayName = queryDisplayName(uri)
            ?.let(::safeDisplayName)
            ?.takeIf { it.isNotEmpty() && it != "." && it != ".." }
            ?: "shared-${index + 1}"
        directory.mkdirs()
        val destination = File(directory, "${UUID.randomUUID()}-$displayName")
        try {
            val input = contentResolver.openInputStream(uri)
                ?: throw ShareImportException(genericImportError)
            var total = 0L
            input.use { source ->
                FileOutputStream(destination).use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        total += read
                        if (total > byteLimit) {
                            throw ShareImportException(
                                if (queueIsLimiting) queueFullError else incomingTooLargeError,
                            )
                        }
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }
            if (total <= 0L) throw ShareImportException(genericImportError)
            return JSONObject()
                .put("path", destination.absolutePath)
                .put("name", displayName)
                .put("mediaType", mediaType)
                .put("byteLength", total)
        } catch (error: ShareImportException) {
            destination.delete()
            throw error
        } catch (_: Exception) {
            destination.delete()
            throw ShareImportException(genericImportError)
        }
    }

    private fun readQueue(): JSONArray {
        val raw = intakePreferences().getString(intakeQueueKey, null) ?: return JSONArray()
        try {
            val queue = JSONArray(raw)
            if (queue.length() > maxPendingRecords) throw ShareImportException(genericImportError)
            for (index in 0 until queue.length()) validateRecord(queue.getJSONObject(index))
            if (queueBytes(queue) > maxPendingBytes) throw ShareImportException(genericImportError)
            return queue
        } catch (error: ShareImportException) {
            throw error
        } catch (_: Exception) {
            throw ShareImportException(genericImportError)
        }
    }

    private fun validateRecord(record: JSONObject) {
        val id = record.optString("id")
        if (!uuidPattern.matches(id) || record.optString("fingerprint").isEmpty()) {
            throw ShareImportException(genericImportError)
        }
        val files = record.optJSONArray("files") ?: throw ShareImportException(genericImportError)
        if (files.length() > maxSharedItems) throw ShareImportException(genericImportError)
        for (index in 0 until files.length()) {
            val file = files.getJSONObject(index)
            val path = file.optString("path")
            val length = file.optLong("byteLength", -1)
            if (path.isEmpty() || file.optString("name").isEmpty() || length <= 0L) {
                throw ShareImportException(genericImportError)
            }
        }
    }

    private fun writeQueue(queue: JSONArray): Boolean {
        val preferences = intakePreferences()
        val previous = preferences.getString(intakeQueueKey, null)
        val editor = preferences.edit()
        if (queue.length() == 0) editor.remove(intakeQueueKey)
        else editor.putString(intakeQueueKey, queue.toString())
        if (editor.commit()) return true

        // commit() updates the process cache before reporting a disk failure.
        // Restore the authoritative queue in memory and best-effort on disk.
        val rollback = preferences.edit()
        if (previous == null) rollback.remove(intakeQueueKey)
        else rollback.putString(intakeQueueKey, previous)
        rollback.commit()
        return false
    }

    private fun oldestPendingPayload(): Map<String, Any?>? = oldestPayload(readQueue())

    private fun oldestPendingPayloadSafely(): Map<String, Any?>? = try {
        oldestPendingPayload()
    } catch (_: Exception) {
        null
    }

    private fun oldestPayload(queue: JSONArray): Map<String, Any?>? =
        if (queue.length() == 0) null else payloadMap(queue.getJSONObject(0))

    private fun payloadMap(record: JSONObject): Map<String, Any?> {
        val files = record.getJSONArray("files")
        return mapOf(
            "id" to record.getString("id"),
            "text" to if (record.isNull("text")) null else record.getString("text"),
            "files" to List(files.length()) { index ->
                val file = files.getJSONObject(index)
                mapOf(
                    "path" to file.getString("path"),
                    "name" to file.getString("name"),
                    "mediaType" to file.getString("mediaType"),
                    "byteLength" to file.getLong("byteLength"),
                )
            },
        )
    }

    private fun queueBytes(queue: JSONArray): Long {
        var total = 0L
        for (recordIndex in 0 until queue.length()) {
            val files = queue.getJSONObject(recordIndex).getJSONArray("files")
            for (fileIndex in 0 until files.length()) {
                total += files.getJSONObject(fileIndex).getLong("byteLength")
            }
        }
        return total
    }

    private fun pruneOrphanedIntake(queue: JSONArray) {
        val retained = mutableSetOf<String>()
        for (index in 0 until queue.length()) retained += queue.getJSONObject(index).getString("id")
        intakeDirectory().listFiles()?.forEach { file ->
            if (file.isDirectory && file.name !in retained) file.deleteRecursively()
        }
    }

    private fun deleteIntakeDirectory(id: String) {
        if (uuidPattern.matches(id)) File(intakeDirectory(), id).deleteRecursively()
    }

    private fun intakeDirectory(): File = File(filesDir, "pending_intake").apply { mkdirs() }

    private fun intakePreferences() =
        getSharedPreferences(intakePreferencesName, MODE_PRIVATE)

    private fun extractSharedText(intent: Intent): String? {
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim().orEmpty()
        return when {
            text.isEmpty() -> subject.ifEmpty { null }
            subject.isEmpty() || text.startsWith(subject) -> text
            else -> "$subject\n\n$text"
        }
    }

    @Suppress("DEPRECATION")
    private fun sharedUris(intent: Intent): List<Uri> {
        val streams = when (intent.action) {
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
            Intent.ACTION_SEND ->
                listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            else -> emptyList()
        }.toMutableList()
        val clip = intent.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) clip.getItemAt(index).uri?.let(streams::add)
        }
        return streams.distinct()
    }

    private fun shareFingerprint(intent: Intent): String {
        val source = buildString {
            append(intent.action.orEmpty()).append('\u0000')
            append(intent.type.orEmpty()).append('\u0000')
            append(extractSharedText(intent).orEmpty()).append('\u0000')
            sharedUris(intent).forEach { append(it.toString()).append('\u0000') }
        }
        return MessageDigest.getInstance("SHA-256")
            .digest(source.toByteArray(Charsets.UTF_8))
            .joinToString("") { (it.toInt() and 0xff).toString(16).padStart(2, '0') }
    }

    private fun queryDisplayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column < 0) null else cursor.getString(column)
        }
    } catch (_: Exception) {
        null
    }

    private fun safeDisplayName(value: String): String =
        value.substringAfterLast('/').substringAfterLast('\\')
            .replace(Regex("[^A-Za-z0-9._() -]"), "_")
            .take(160)

    private fun postResult(result: MethodChannel.Result, value: Any?) {
        runOnUiThread { result.success(value) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        runOnUiThread { result.error(code, message, null) }
    }

    private fun postSharePayload(payload: Map<String, Any?>?) {
        if (payload != null) runOnUiThread { shareChannel?.invokeMethod("sharePayload", payload) }
    }

    private fun postShareError(message: String) {
        runOnUiThread { shareChannel?.invokeMethod("shareError", message) }
    }

    private fun safeImportMessage(error: Exception): String =
        (error as? ShareImportException)?.safeMessage ?: genericImportError

    private fun clearConsumedShareIntent(consumed: Intent) {
        runOnUiThread {
            if (intent !== consumed) return@runOnUiThread
            setIntent(
                Intent(consumed).apply {
                    action = null
                    type = null
                    clipData = null
                    removeExtra(Intent.EXTRA_TEXT)
                    removeExtra(Intent.EXTRA_SUBJECT)
                    removeExtra(Intent.EXTRA_STREAM)
                },
            )
        }
    }

    private class ShareImportException(val safeMessage: String) : Exception()

    companion object {
        private val intakeExecutor = Executors.newSingleThreadExecutor()
        private val uuidPattern = Regex(
            "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
        )
        private const val tooManyFilesError = "You can share up to 10 files at once."
        private const val incomingTooLargeError = "Shared files are limited to 64 MiB at once."
        private const val queueFullError =
            "Shared draft storage is full. Add or discard a pending share first."
        private const val textTooLargeError = "Shared text is too large to import."
        private const val genericImportError =
            "Shared content could not be imported. Try sharing it again."
        private const val genericAcknowledgeError =
            "The pending share could not be cleared. Try again."
    }
}
