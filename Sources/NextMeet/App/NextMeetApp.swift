import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct NextMeetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = MeetingStore(provider: EventKitMeetingProvider())
    @StateObject private var launchAtLoginStore = LaunchAtLoginStore()

    var body: some Scene {
        MenuBarExtra("NextMeet", systemImage: "calendar.badge.clock") {
            NextMeetMenuView(store: store, launchAtLoginStore: launchAtLoginStore)
                .onAppear {
                    Task {
                        await store.refresh()
                    }
                    launchAtLoginStore.refresh()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
