package com.mizan.mizan

import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity, as local_auth's biometric prompt needs one.
class MainActivity : FlutterFragmentActivity() {
    // The save waiting on the picker; one at a time.
    private var pending: PendingSave? = null

    private class PendingSave(val bytes: ByteArray, val result: MethodChannel.Result)

    // Registered at construction, as the Activity Result API requires. The
    // MIME type is fixed here; the CSV export is the only caller.
    private val createDocument =
        registerForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
            val save = pending ?: return@registerForActivityResult
            pending = null
            if (uri == null) {
                save.result.success(false) // cancelled
            } else {
                write(uri, save)
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mizan/file_export")
            .setMethodCallHandler { call, result ->
                if (call.method != "save") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val fileName = call.argument<String>("fileName")
                val bytes = call.argument<ByteArray>("bytes")
                when {
                    fileName == null || bytes == null ->
                        result.error("bad_args", "fileName and bytes are required", null)
                    pending != null ->
                        result.error("busy", "A save is already open", null)
                    else -> {
                        pending = PendingSave(bytes, result)
                        createDocument.launch(fileName)
                    }
                }
            }
    }

    private fun write(uri: Uri, save: PendingSave) {
        try {
            val stream = contentResolver.openOutputStream(uri, "wt")
                ?: throw IllegalStateException("No output stream for $uri")
            stream.use { it.write(save.bytes) }
            save.result.success(true)
        } catch (e: Exception) {
            save.result.error("write_failed", e.message, null)
        }
    }
}
