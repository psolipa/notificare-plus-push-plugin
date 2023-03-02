import NotificareKit
import NotificarePushKit

@objc(NotificarePushPlugin)
class NotificarePushPlugin : CDVPlugin {

    override func pluginInitialize() {
        super.pluginInitialize()

        Notificare.shared.push().delegate = self
    }

    @objc func registerListener(_ command: CDVInvokedUrlCommand) {
        NotificarePushPluginEventBroker.startListening(settings: commandDelegate.settings) { event in
            var payload: [String: Any] = [
                "name": event.name,
            ]

            if let data = event.payload {
                payload["data"] = data
            }

            let result = CDVPluginResult(status: .ok, messageAs: payload)
            result!.keepCallback = true

            self.commandDelegate!.send(result, callbackId: command.callbackId)
        }
    }

    // MARK: - Notificare Push

    @objc
    func setAuthorizationOptions(_ command: CDVInvokedUrlCommand) {
        let options = command.argument(at: 0) as! [String]
        var authorizationOptions: UNAuthorizationOptions = []

        options.forEach { option in
            if option == "alert" {
                authorizationOptions = [authorizationOptions, .alert]
            }

            if option == "badge" {
                authorizationOptions = [authorizationOptions, .badge]
            }

            if option == "sound" {
                authorizationOptions = [authorizationOptions, .sound]
            }

            if option == "carPlay" {
                authorizationOptions = [authorizationOptions, .carPlay]
            }

            if #available(iOS 12.0, *) {
                if option == "providesAppNotificationSettings" {
                    authorizationOptions = [authorizationOptions, .providesAppNotificationSettings]
                }

                if option == "provisional" {
                    authorizationOptions = [authorizationOptions, .provisional]
                }

                if option == "criticalAlert" {
                    authorizationOptions = [authorizationOptions, .criticalAlert]
                }
            }

            if #available(iOS 13.0, *) {
                if option == "announcement" {
                    authorizationOptions = [authorizationOptions, .announcement]
                }
            }
        }

        Notificare.shared.push().authorizationOptions = authorizationOptions

        let result = CDVPluginResult(status: .ok)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc
    func setCategoryOptions(_ command: CDVInvokedUrlCommand) {
        let options = command.argument(at: 0) as! [String]
        var categoryOptions: UNNotificationCategoryOptions = []

        options.forEach { option in
            if option == "customDismissAction" {
                categoryOptions = [categoryOptions, .customDismissAction]
            }

            if option == "allowInCarPlay" {
                categoryOptions = [categoryOptions, .allowInCarPlay]
            }

            if #available(iOS 11.0, *) {
                if option == "hiddenPreviewsShowTitle" {
                    categoryOptions = [categoryOptions, .hiddenPreviewsShowTitle]
                }

                if option == "hiddenPreviewsShowSubtitle" {
                    categoryOptions = [categoryOptions, .hiddenPreviewsShowSubtitle]
                }
            }

            if #available(iOS 13.0, *) {
                if option == "allowAnnouncement" {
                    categoryOptions = [categoryOptions, .allowAnnouncement]
                }
            }
        }

        Notificare.shared.push().categoryOptions = categoryOptions

        let result = CDVPluginResult(status: .ok)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc
    func setPresentationOptions(_ command: CDVInvokedUrlCommand) {
        let options = command.argument(at: 0) as! [String]
        var presentationOptions: UNNotificationPresentationOptions = []

        options.forEach { option in
            if #available(iOS 14.0, *) {
                if option == "banner" || option == "alert" {
                    presentationOptions = [presentationOptions, .banner]
                }

                if option == "list" {
                    presentationOptions = [presentationOptions, .list]
                }
            } else {
                if option == "alert" {
                    presentationOptions = [presentationOptions, .alert]
                }
            }

            if option == "badge" {
                presentationOptions = [presentationOptions, .badge]
            }

            if option == "sound" {
                presentationOptions = [presentationOptions, .sound]
            }
        }

        Notificare.shared.push().presentationOptions = presentationOptions

        let result = CDVPluginResult(status: .ok)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc func hasRemoteNotificationsEnabled(_ command: CDVInvokedUrlCommand) {
        let result = CDVPluginResult(status: .ok, messageAs: Notificare.shared.push().hasRemoteNotificationsEnabled)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc func allowedUI(_ command: CDVInvokedUrlCommand) {
        let result = CDVPluginResult(status: .ok, messageAs: Notificare.shared.push().allowedUI)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc func enableRemoteNotifications(_ command: CDVInvokedUrlCommand) {
        Notificare.shared.push().enableRemoteNotifications { result in
            switch result {
            case .success:
                let result = CDVPluginResult(status: .ok)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            case let .failure(error):
                let result = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            }
        }
    }

    @objc func disableRemoteNotifications(_ command: CDVInvokedUrlCommand) {
        Notificare.shared.push().disableRemoteNotifications()

        let result = CDVPluginResult(status: .ok)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc func checkPermissionStatus(_ command: CDVInvokedUrlCommand) {
        checkPermissionStatus { status in
            let result = CDVPluginResult(status: .ok, messageAs: status.rawValue)
            self.commandDelegate!.send(result, callbackId: command.callbackId)
        }
    }

    @objc func shouldShowPermissionRationale(_ command: CDVInvokedUrlCommand) {
        let result = CDVPluginResult(status: .ok, messageAs: false)
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc func presentPermissionRationale(_ command: CDVInvokedUrlCommand) {
        let result = CDVPluginResult(status: .error, messageAs: "This method is not implemented in iOS.")
        self.commandDelegate!.send(result, callbackId: command.callbackId)
    }

    @objc func requestPermission(_ command: CDVInvokedUrlCommand) {
        checkPermissionStatus { status in
            guard status != .granted && status != .permanentlyDenied else {
                let result = CDVPluginResult(status: .ok, messageAs: status.rawValue)
                self.commandDelegate!.send(result, callbackId: command.callbackId)
                return
            }

            let authorizationOptions = Notificare.shared.push().authorizationOptions

            UNUserNotificationCenter.current().requestAuthorization(options: authorizationOptions) { (granted, error) in
                if error == nil {
                    let result = CDVPluginResult(status: .ok, messageAs: granted ? ["result": PermissionStatus.granted.rawValue] : ["result": PermissionStatus.denied.rawValue])
                    self.commandDelegate!.send(result, callbackId: command.callbackId)
                    return
                }

                let result = CDVPluginResult(status: .error, messageAs: "Unable to request notifications permission.")
                self.commandDelegate!.send(result, callbackId: command.callbackId)
            }
        }
    }

    @objc func openAppSettings(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) else {
                let result = CDVPluginResult(status: .error, messageAs: "Unable to open the application settings.")
                self.commandDelegate!.send(result, callbackId: command.callbackId)
                return
            }

            UIApplication.shared.open(url) { success in
                if success {
                    let result = CDVPluginResult(status: .ok)
                    self.commandDelegate!.send(result, callbackId: command.callbackId)
                } else {
                    let result = CDVPluginResult(status: .error, messageAs: "Unable to open the application settings.")
                    self.commandDelegate!.send(result, callbackId: command.callbackId)
                }
            }
        }
    }

    private func checkPermissionStatus(_ completion: @escaping (PermissionStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { status in
            var permissionStatus = PermissionStatus.denied

            if status.authorizationStatus == .authorized {
                permissionStatus = PermissionStatus.granted
            }

            if status.authorizationStatus == .denied {
                permissionStatus = PermissionStatus.permanentlyDenied
            }

            completion(permissionStatus)
        }
    }
}

extension NotificarePushPlugin: NotificarePushDelegate {
    func notificare(_ notificarePush: NotificarePush, didReceiveNotification notification: NotificareNotification) {
        do {
            NotificarePushPluginEventBroker.dispatchEvent(
                name: "notification_received",
                payload: try notification.toJson()
            )
        } catch {
            NotificareLogger.error("Failed to emit the notification_received event.", error: error)
        }
    }

    func notificare(_ notificarePush: NotificarePush, didReceiveNotification notification: NotificareNotification, deliveryMechanism: NotificareNotificationDeliveryMechanism) {
        do {
            let payload: [String: Any] = [
                "notification": try notification.toJson(),
                "deliveryMechanism": deliveryMechanism.rawValue,
            ]

            NotificarePushPluginEventBroker.dispatchEvent(
                name: "notification_info_received",
                payload: payload
            )
        } catch {
            NotificareLogger.error("Failed to emit the notification_info_received event.", error: error)
        }
    }

    func notificare(_ notificarePush: NotificarePush, didReceiveSystemNotification notification: NotificareSystemNotification) {
        do {
            NotificarePushPluginEventBroker.dispatchEvent(
                name: "system_notification_received",
                payload: try notification.toJson()
            )
        } catch {
            NotificareLogger.error("Failed to emit the system_notification_received event.", error: error)
        }
    }

    func notificare(_ notificarePush: NotificarePush, didReceiveUnknownNotification userInfo: [AnyHashable : Any]) {
        NotificarePushPluginEventBroker.dispatchEvent(
            name: "unknown_notification_received",
            payload: userInfo
        )
    }

    func notificare(_ notificarePush: NotificarePush, didOpenNotification notification: NotificareNotification) {
        do {
            NotificarePushPluginEventBroker.dispatchEvent(
                name: "notification_opened",
                payload: try notification.toJson()
            )
        } catch {
            NotificareLogger.error("Failed to emit the notification_opened event.", error: error)
        }
    }

    func notificare(_ notificarePush: NotificarePush, didOpenUnknownNotification userInfo: [AnyHashable : Any]) {
        let payload: [String: Any] = Dictionary(uniqueKeysWithValues: userInfo.compactMap {
            guard let key = $0.key as? String else {
                return nil
            }

            return (key, $0.value)
        })

        NotificarePushPluginEventBroker.dispatchEvent(
            name: "unknown_notification_opened",
            payload: payload
        )
    }

    func notificare(_ notificarePush: NotificarePush, didOpenAction action: NotificareNotification.Action, for notification: NotificareNotification) {
        do {
            let payload = [
                "notification": try notification.toJson(),
                "action": try action.toJson(),
            ]

            NotificarePushPluginEventBroker.dispatchEvent(
                name: "notification_action_opened",
                payload: payload
            )
        } catch {
            NotificareLogger.error("Failed to emit the notification_action_opened event.", error: error)
        }
    }

    func notificare(_ notificarePush: NotificarePush, didOpenUnknownAction action: String, for notification: [AnyHashable : Any], responseText: String?) {
        let notificationMap: [String: Any] = Dictionary(uniqueKeysWithValues: notification.compactMap {
            guard let key = $0.key as? String else {
                return nil
            }

            return (key, $0.value)
        })

        var data: [String: Any] = [
            "notification": notificationMap,
            "action": action,
        ]

        if let responseText = responseText {
            data["responseText"] = responseText
        }

        NotificarePushPluginEventBroker.dispatchEvent(
            name: "unknown_notification_action_opened",
            payload: data
        )
    }

    func notificare(_ notificarePush: NotificarePush, didChangeNotificationSettings granted: Bool) {
        NotificarePushPluginEventBroker.dispatchEvent(
            name: "notification_settings_changed",
            payload: granted
        )
    }

    func notificare(_ notificarePush: NotificarePush, shouldOpenSettings notification: NotificareNotification?) {
        do {
            NotificarePushPluginEventBroker.dispatchEvent(
                name: "should_open_notification_settings",
                payload: try notification?.toJson()
            )
        } catch {
            NotificareLogger.error("Failed to emit the should_open_notification_settings event.", error: error)
        }
    }

    func notificare(_ notificarePush: NotificarePush, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificarePushPluginEventBroker.dispatchEvent(
            name: "failed_to_register_for_remote_notifications",
            payload: error.localizedDescription
        )
    }
}

extension NotificarePushPlugin {
    internal enum PermissionStatus: String, CaseIterable {
        case denied = "denied"
        case granted = "granted"
        case permanentlyDenied = "permanently_denied"
    }
}
