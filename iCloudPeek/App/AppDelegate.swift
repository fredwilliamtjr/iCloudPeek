import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var monitor = SyncMonitor(store: SyncStore.shared)
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Notifications.requestAuthorization()

        SyncStore.shared.onQueueEmptied = {
            Notifications.postQueueEmpty()
        }

        menuBarController = MenuBarController(store: SyncStore.shared)
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}
