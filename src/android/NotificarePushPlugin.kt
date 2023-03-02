package re.notifica.push.cordova

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AlertDialog
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Observer
import org.apache.cordova.CallbackContext
import org.apache.cordova.CordovaArgs
import org.apache.cordova.CordovaPlugin
import org.apache.cordova.PluginResult
import org.json.JSONArray
import org.json.JSONObject
import re.notifica.Notificare
import re.notifica.internal.NotificareLogger
import re.notifica.push.ktx.push

class NotificarePushPlugin : CordovaPlugin() {
    private var shouldShowRationale = false
    private var hasOnGoingPermissionRequest = false
    private var permissionRequestCallback: CallbackContext? = null

    private lateinit var notificationsPermissionLauncher: ActivityResultLauncher<String>

    private val allowedUIObserver = Observer<Boolean> { allowedUI ->
        if (allowedUI == null) return@Observer

        NotificarePushPluginEventBroker.dispatchEvent("notification_settings_changed", allowedUI)
    }

    override fun pluginInitialize() {
        Notificare.push().intentReceiver = NotificarePushPluginReceiver::class.java

        onMainThread {
            Notificare.push().observableAllowedUI.observeForever(allowedUIObserver)
        }

        val intent = cordova.activity.intent
        if (intent != null) onNewIntent(intent)

        notificationsPermissionLauncher = cordova.activity.registerForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { granted ->
            if (granted) {
                permissionRequestCallback?.success(PermissionStatus.GRANTED.rawValue)
            } else {
                if (!shouldShowRationale &&
                    !ActivityCompat.shouldShowRequestPermissionRationale(cordova.activity, PUSH_PERMISSION)
                ) {
                    permissionRequestCallback?.success(PermissionStatus.PERMANENTLY_DENIED.rawValue)
                } else {
                    permissionRequestCallback?.success(PermissionStatus.DENIED.rawValue)
                }
            }

            shouldShowRationale = false
            hasOnGoingPermissionRequest = false
            permissionRequestCallback = null
        }
    }

    override fun onDestroy() {
        onMainThread {
            Notificare.push().observableAllowedUI.removeObserver(allowedUIObserver)
        }
    }

    override fun onNewIntent(intent: Intent) {
        Notificare.push().handleTrampolineIntent(intent)
    }

    override fun execute(action: String, args: CordovaArgs, callback: CallbackContext): Boolean {
        when (action) {
            "setAuthorizationOptions" -> setAuthorizationOptions(args, callback)
            "setCategoryOptions" -> setCategoryOptions(args, callback)
            "setPresentationOptions" -> setPresentationOptions(args, callback)
            "hasRemoteNotificationsEnabled" -> hasRemoteNotificationsEnabled(args, callback)
            "allowedUI" -> allowedUI(args, callback)
            "enableRemoteNotifications" -> enableRemoteNotifications(args, callback)
            "disableRemoteNotifications" -> disableRemoteNotifications(args, callback)
            "checkPermissionStatus" -> checkPermissionStatus(args, callback)
            "shouldShowPermissionRationale" -> shouldShowPermissionRationale(args, callback)
            "presentPermissionRationale" -> presentPermissionRationale(args, callback)
            "requestPermission" -> requestPermission(args, callback)
            "openAppSettings" -> openAppSettings(args, callback)

            // Event broker
            "registerListener" -> registerListener(args, callback)

            else -> {
                callback.error("No implementation for action '$action'.")
                return false
            }
        }

        return true
    }

    // region Notificare Push

    private fun setAuthorizationOptions(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        // no-op: iOS-only method
        callback.void()
    }

    private fun setCategoryOptions(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        // no-op: iOS-only method
        callback.void()
    }

    private fun setPresentationOptions(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        // no-op: iOS-only method
        callback.void()
    }

    private fun hasRemoteNotificationsEnabled(
        @Suppress("UNUSED_PARAMETER") args: CordovaArgs,
        callback: CallbackContext
    ) {
        callback.success(Notificare.push().hasRemoteNotificationsEnabled)
    }

    private fun allowedUI(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        callback.success(Notificare.push().allowedUI)
    }

    private fun enableRemoteNotifications(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        Notificare.push().enableRemoteNotifications()
        callback.void()
    }

    private fun disableRemoteNotifications(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        Notificare.push().disableRemoteNotifications()
        callback.void()
    }

    // endregion

    // region Notificare Push

    private fun checkPermissionStatus(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        val context = cordova.context ?: run {
            callback.error("Cannot continue without a context.")
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            val granted = NotificationManagerCompat.from(context.applicationContext).areNotificationsEnabled()
            callback.success(if (granted) PermissionStatus.GRANTED.rawValue else PermissionStatus.PERMANENTLY_DENIED.rawValue)
            return
        }

        val granted = ContextCompat.checkSelfPermission(context, PUSH_PERMISSION) == PackageManager.PERMISSION_GRANTED
        callback.success(if (granted) PermissionStatus.GRANTED.rawValue else PermissionStatus.DENIED.rawValue)
    }

    private fun shouldShowPermissionRationale(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            callback.success(false)
            return
        }

        val activity = cordova.activity ?: run {
            NotificareLogger.warning("Unable to acquire a reference to the current activity.")
            callback.error("Unable to acquire a reference to the current activity.")
            return
        }

        val result = ActivityCompat.shouldShowRequestPermissionRationale(activity, PUSH_PERMISSION)

        callback.success(result)
    }

    private fun presentPermissionRationale(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        val activity = cordova.activity ?: run {
            NotificareLogger.warning("Unable to acquire a reference to the current activity.")
            callback.error("Unable to acquire a reference to the current activity.")
            return
        }

        val rationale =
            if (!args.isNull(0)) {
                args.getJSONObject(0)
            } else {
                callback.error("Missing rationale parameter.")
                return
            }

        val title = if (!rationale.isNull("title")) rationale.getString("title") else null
        val message =
            if (!rationale.isNull("message")) {
                rationale.getString("message")
            } else {
                callback.error("Missing message parameter.")
                return
            }
        val buttonText =
            if (!rationale.isNull("buttonText")) rationale.getString("buttonText")
            else activity.getString(android.R.string.ok)

        try {
            NotificareLogger.debug("Presenting permission rationale for notifications.")

            activity.runOnUiThread {
                AlertDialog.Builder(activity)
                    .setTitle(title)
                    .setMessage(message)
                    .setCancelable(false)
                    .setPositiveButton(buttonText, null)
                    .setOnDismissListener { callback.success() }
                    .show()
            }
        } catch (e: Exception) {
            callback.error("Unable to present the rationale alert.")
        }
    }

    private fun requestPermission(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        val activity = cordova.activity ?: run {
            callback.error("Cannot continue without a activity.")
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            val granted = NotificationManagerCompat.from(activity.applicationContext).areNotificationsEnabled()
            callback.success(if (granted) PermissionStatus.GRANTED.rawValue else PermissionStatus.PERMANENTLY_DENIED.rawValue)
            return
        }

        if (hasOnGoingPermissionRequest) {
            NotificareLogger.warning("A request for permissions is already running, please wait for it to finish before doing another request.")
            callback.error("A request for permissions is already running, please wait for it to finish before doing another request.")
            return
        }

        val granted = ContextCompat.checkSelfPermission(activity, PUSH_PERMISSION) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            callback.success(PermissionStatus.GRANTED.rawValue)
            return
        }

        shouldShowRationale = ActivityCompat.shouldShowRequestPermissionRationale(activity, PUSH_PERMISSION)
        hasOnGoingPermissionRequest = true
        permissionRequestCallback = callback

        notificationsPermissionLauncher.launch(PUSH_PERMISSION)
    }

    private fun openAppSettings(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        try {
            val context = cordova.context ?: run {
                callback.error("Cannot continue without a context.")
                return
            }

            val packageName = Uri.fromParts("package", context.packageName, null)
            context.startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageName)
                    .addCategory(Intent.CATEGORY_DEFAULT)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                    .addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            )

            callback.void()
        } catch (e: Exception) {
            callback.error("Unable to open the app settings.")
        }
    }

    // endregion

    private fun registerListener(@Suppress("UNUSED_PARAMETER") args: CordovaArgs, callback: CallbackContext) {
        NotificarePushPluginEventBroker.setup(preferences, object : NotificarePushPluginEventBroker.Consumer {
            override fun onEvent(event: NotificarePushPluginEventBroker.Event) {
                val payload = JSONObject()
                payload.put("name", event.name)
                when (event.payload) {
                    null -> {} // Skip encoding null payloads.
                    is Boolean -> payload.put("data", event.payload)
                    is Int -> payload.put("data", event.payload)
                    is Float -> payload.put("data", event.payload)
                    is Double -> payload.put("data", event.payload)
                    is String -> payload.put("data", event.payload)
                    is JSONObject -> payload.put("data", event.payload)
                    is JSONArray -> payload.put("data", event.payload)
                    else -> throw IllegalArgumentException("Unsupported event payload of type '${event.payload::class.java.simpleName}'.")
                }

                val result = PluginResult(PluginResult.Status.OK, payload)
                result.keepCallback = true

                callback.sendPluginResult(result)
            }
        })
    }

    private companion object {
        @RequiresApi(Build.VERSION_CODES.TIRAMISU)
        private const val PUSH_PERMISSION = Manifest.permission.POST_NOTIFICATIONS
    }

    internal enum class PermissionStatus {
        DENIED,
        GRANTED,
        PERMANENTLY_DENIED;

        internal val rawValue: String
            get() = when (this) {
                DENIED -> "denied"
                GRANTED -> "granted"
                PERMANENTLY_DENIED -> "permanently_denied"
            }

        internal companion object {
            internal fun parse(status: String): PermissionStatus? {
                values().forEach {
                    if (it.rawValue == status) return it
                }

                return null
            }
        }
    }
}

private fun onMainThread(action: () -> Unit) = Handler(Looper.getMainLooper()).post(action)

private fun CallbackContext.void() {
    sendPluginResult(PluginResult(PluginResult.Status.OK, null as String?))
}

private fun CallbackContext.success(b: Boolean) {
    sendPluginResult(PluginResult(PluginResult.Status.OK, b))
}
