import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let meetingStore = MeetingStore(provider: EventKitMeetingProvider())
        let launchAtLoginStore = LaunchAtLoginStore()
        let reminderPreferencesStore = ReminderPreferencesStore()
        let reminderController = MeetingReminderController(
            store: meetingStore,
            preferencesStore: reminderPreferencesStore,
            scheduler: MeetingReminderScheduler()
        )

        statusItemController = StatusItemController(
            store: meetingStore,
            launchAtLoginStore: launchAtLoginStore,
            reminderPreferencesStore: reminderPreferencesStore,
            reminderController: reminderController
        )
    }
}

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let viewController: NextMeetPopoverViewController
    private let aboutWindowController: AboutWindowController
    private let reminderController: MeetingReminderController

    init(
        store: MeetingStore,
        launchAtLoginStore: LaunchAtLoginStore,
        reminderPreferencesStore: ReminderPreferencesStore,
        reminderController: MeetingReminderController
    ) {
        let aboutWindowController = AboutWindowController()
        self.aboutWindowController = aboutWindowController
        self.reminderController = reminderController
        viewController = NextMeetPopoverViewController(
            store: store,
            launchAtLoginStore: launchAtLoginStore,
            reminderPreferencesStore: reminderPreferencesStore,
            onShowAbout: { [weak aboutWindowController] in
                aboutWindowController?.present()
            }
        )

        super.init()

        if let button = statusItem.button {
            if let image = statusImage() {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "NM"
            }

            button.toolTip = "NextMeet"
            button.target = self
            button.action = #selector(togglePopover)
        }
        statusItem.isVisible = true

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 390, height: 140)
        popover.contentViewController = viewController
        popover.delegate = self

        reminderController.start()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else {
            return
        }

        viewController.refreshForPresentation()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func popoverDidClose(_ notification: Notification) {
        viewController.cancelKeyboardMonitoring()
    }

    private func statusImage() -> NSImage? {
        let symbolNames = [
            "calendar.badge.clock",
            "calendar"
        ]

        for symbolName in symbolNames {
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "NextMeet") {
                return image
            }
        }

        return nil
    }
}
