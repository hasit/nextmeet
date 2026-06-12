import AppKit
import SwiftUI

struct NextMeetMenuView: View {
    @ObservedObject var store: MeetingStore
    @ObservedObject var launchAtLoginStore: LaunchAtLoginStore
    @State private var hoveredRow: MenuRow?

    var body: some View {
        VStack(spacing: 6) {
            if store.isRefreshing {
                loadingRow
            }

            meetingItems

            Divider()

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                actionRow(
                    title: store.isRefreshing ? "Refreshing" : "Refresh",
                    systemImage: "arrow.clockwise",
                    shortcut: "⌘R",
                    row: .refresh,
                    isEnabled: !store.isRefreshing
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .keyboardShortcut("r")

            Button {
                launchAtLoginStore.setEnabled(!launchAtLoginStore.isEnabled)
            } label: {
                actionRow(
                    title: "Launch at Startup",
                    systemImage: "powerplug",
                    accessory: launchAtLoginStore.isEnabled ? "On" : "Off",
                    row: .launchAtStartup
                )
            }
            .buttonStyle(.plain)
            .help(launchAtLoginStore.helpText)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                actionRow(title: "Quit", systemImage: "power", shortcut: "⌘Q", row: .quit)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(width: 390)
    }

    fileprivate enum MenuRow: Hashable {
        case refresh
        case launchAtStartup
        case quit
        case meeting(String)
    }

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Refreshing meetings...")
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .frame(height: 22)
    }

    private func actionRow(
        title: String,
        systemImage: String,
        shortcut: String,
        row: MenuRow,
        isEnabled: Bool = true
    ) -> some View {
        actionRow(title: title, systemImage: systemImage, accessory: shortcut, row: row, isEnabled: isEnabled)
    }

    private func actionRow(
        title: String,
        systemImage: String,
        accessory: String,
        row: MenuRow,
        isEnabled: Bool = true
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .frame(width: 14)
                .foregroundStyle(.secondary)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 12)
            Text(accessory)
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 13, weight: .medium))
        .menuRowHighlight(
            row: row,
            hoveredRow: $hoveredRow,
            isEnabled: isEnabled
        )
    }

    private func meetingRow(_ meeting: MeetingLink) -> some View {
        let row = MenuRow.meeting(meeting.id)

        return Button {
            store.open(meeting)
        } label: {
            HStack(spacing: 0) {
                Text(meeting.menuTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: .semibold))
            .menuRowHighlight(row: row, hoveredRow: $hoveredRow)
        }
        .buttonStyle(.plain)
        .help(meeting.helpText)
    }

    @ViewBuilder
    private var meetingItems: some View {
        if store.meetings.isEmpty {
            if !store.isRefreshing {
                Text(store.status.menuMessage)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            }
        } else {
            ForEach(store.meetings) { meeting in
                meetingRow(meeting)
            }
        }
    }
}

private extension View {
    func menuRowHighlight(
        row: NextMeetMenuView.MenuRow,
        hoveredRow: Binding<NextMeetMenuView.MenuRow?>,
        isEnabled: Bool = true
    ) -> some View {
        modifier(MenuRowHighlightModifier(row: row, hoveredRow: hoveredRow, isEnabled: isEnabled))
    }
}

private struct MenuRowHighlightModifier: ViewModifier {
    let row: NextMeetMenuView.MenuRow
    @Binding var hoveredRow: NextMeetMenuView.MenuRow?
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 23)
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .background {
                if hoveredRow == row && isEnabled {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                }
            }
            .onHover { isHovering in
                guard isEnabled else {
                    return
                }

                hoveredRow = isHovering ? row : (hoveredRow == row ? nil : hoveredRow)
            }
    }
}
