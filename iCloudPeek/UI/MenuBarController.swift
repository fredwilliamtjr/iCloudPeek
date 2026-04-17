import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private let store: SyncStore
    private var cancellables: Set<AnyCancellable> = []
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(store: SyncStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.hasShadow = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        self.panel = panel

        super.init()

        let hosting = NSHostingController(rootView: LivePopoverView().environmentObject(store))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 400, height: 520)
        panel.contentViewController = hosting

        if let button = statusItem.button {
            button.action = #selector(toggle(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        store.objectWillChange
            .throttle(for: .milliseconds(250), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in self?.refreshIcon() }
            .store(in: &cancellables)

        refreshIcon()
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let name: String
        switch store.aggregateActivity {
        case .uploading: name = "icloud.and.arrow.up"
        case .downloading: name = "icloud.and.arrow.down"
        case .idle: name = "icloud"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "iCloud")
        image?.isTemplate = true
        button.image = image

        let count = store.totalInFlight
        button.title = count > 0 ? " \(count)" : ""
        button.toolTip = count > 0 ? store.summary : "iCloudPeek — tudo sincronizado"
    }

    @objc private func toggle(_ sender: Any?) {
        if panel.isVisible {
            close()
        } else {
            show()
        }
    }

    private func show() {
        guard let button = statusItem.button,
              let buttonWindow = button.window
        else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        var origin = NSPoint(
            x: screenRect.midX - panel.frame.width / 2,
            y: screenRect.minY - panel.frame.height - 6
        )
        if let screen = NSScreen.main {
            origin.x = max(8, min(origin.x, screen.visibleFrame.maxX - panel.frame.width - 8))
        }

        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        panel.makeKey()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window !== self.panel {
                self.close()
            }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func close() {
        panel.orderOut(nil)
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
}
