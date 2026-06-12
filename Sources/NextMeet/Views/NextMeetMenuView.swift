import AppKit

@MainActor
final class NextMeetPopoverViewController: NSViewController {
    private let store: MeetingStore
    private let launchAtLoginStore: LaunchAtLoginStore
    private let stackView = NSStackView()

    private var keyboardMonitor: Any?

    init(store: MeetingStore, launchAtLoginStore: LaunchAtLoginStore) {
        self.store = store
        self.launchAtLoginStore = launchAtLoginStore

        super.init(nibName: nil, bundle: nil)

        store.onChange = { [weak self] in
            self?.reloadContent()
        }
        launchAtLoginStore.onChange = { [weak self] in
            self?.reloadContent()
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let view = KeyHandlingView(frame: NSRect(x: 0, y: 0, width: 390, height: 140))
        view.onRefresh = { [weak self] in
            self?.refresh()
        }
        view.onQuit = {
            NSApplication.shared.terminate(nil)
        }

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadContent()
    }

    func refreshForPresentation() {
        launchAtLoginStore.refresh()
        reloadContent()
        installKeyboardMonitoring()
        refresh()
    }

    func cancelKeyboardMonitoring() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    private func refresh() {
        Task {
            await store.refresh()
        }
    }

    private func reloadContent() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if store.meetings.isEmpty {
            stackView.addArrangedSubview(store.isRefreshing ? loadingRow() : messageRow(store.status.menuMessage))
        } else {
            for meeting in store.meetings {
                stackView.addArrangedSubview(meetingRow(meeting))
            }
        }

        stackView.addArrangedSubview(separator())
        stackView.addArrangedSubview(refreshRow())
        stackView.addArrangedSubview(launchAtStartupRow())
        stackView.addArrangedSubview(quitRow())

        updatePreferredSize()
    }

    private func updatePreferredSize() {
        view.layoutSubtreeIfNeeded()

        let height = max(104, stackView.fittingSize.height + 16)
        preferredContentSize = NSSize(width: 390, height: height)
    }

    private func installKeyboardMonitoring() {
        cancelKeyboardMonitoring()

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifierFlags.contains(.command),
                  let characters = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }

            if characters == "r" {
                self.refresh()
                return nil
            }

            if characters == "q" {
                NSApplication.shared.terminate(nil)
                return nil
            }

            return event
        }
    }

    private func loadingRow() -> NSView {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.widthAnchor.constraint(equalToConstant: 14).isActive = true
        indicator.startAnimation(nil)

        let label = label("Refreshing meetings...", color: .secondaryLabelColor)
        let row = horizontalStack([indicator, label, spacer()])
        row.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return row
    }

    private func messageRow(_ message: String) -> NSView {
        let row = horizontalStack([label(message, color: .secondaryLabelColor), spacer()])
        row.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return row
    }

    private func meetingRow(_ meeting: MeetingLink) -> NSView {
        let row = MenuRowControl(title: meeting.menuTitle, fontWeight: .semibold)
        row.toolTip = meeting.helpText
        row.representedObject = meeting
        row.target = self
        row.action = #selector(openMeeting(_:))
        return row
    }

    private func refreshRow() -> NSView {
        let row = MenuRowControl(
            title: store.isRefreshing ? "Refreshing..." : "Refresh",
            systemImageName: store.isRefreshing ? nil : "arrow.clockwise",
            accessory: "⌘R",
            showsSpinner: store.isRefreshing
        )
        row.target = self
        row.action = #selector(refreshAction(_:))
        return row
    }

    private func launchAtStartupRow() -> NSView {
        let row = MenuRowControl(
            title: "Launch at Startup",
            systemImageName: "powerplug",
            accessory: launchAtLoginStore.isEnabled ? "On" : "Off"
        )
        row.toolTip = launchAtLoginStore.helpText
        row.target = self
        row.action = #selector(toggleLaunchAtStartup(_:))
        return row
    }

    private func quitRow() -> NSView {
        let row = MenuRowControl(title: "Quit", systemImageName: "power", accessory: "⌘Q")
        row.target = self
        row.action = #selector(quit(_:))
        return row
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        box.widthAnchor.constraint(equalToConstant: 362).isActive = true
        return box
    }

    private func horizontalStack(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 362).isActive = true
        return stack
    }

    private func label(_ text: String, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }

    private func spacer() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return spacer
    }

    @objc private func openMeeting(_ sender: MenuRowControl) {
        guard let meeting = sender.representedObject as? MeetingLink else {
            return
        }

        store.open(meeting)
    }

    @objc private func refreshAction(_ sender: MenuRowControl) {
        refresh()
    }

    @objc private func toggleLaunchAtStartup(_ sender: MenuRowControl) {
        launchAtLoginStore.setEnabled(!launchAtLoginStore.isEnabled)
    }

    @objc private func quit(_ sender: MenuRowControl) {
        NSApplication.shared.terminate(nil)
    }
}

private final class KeyHandlingView: NSView {
    var onRefresh: (() -> Void)?
    var onQuit: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifierFlags.contains(.command),
           let characters = event.charactersIgnoringModifiers?.lowercased() {
            if characters == "r" {
                onRefresh?()
                return
            }

            if characters == "q" {
                onQuit?()
                return
            }
        }

        super.keyDown(with: event)
    }
}

private final class MenuRowControl: NSControl {
    var representedObject: Any?

    private let contentStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let accessoryLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(
        title: String,
        systemImageName: String? = nil,
        accessory: String? = nil,
        fontWeight: NSFont.Weight = .medium,
        isEnabled: Bool = true,
        showsSpinner: Bool = false
    ) {
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 5
        self.isEnabled = isEnabled

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 23).isActive = true
        widthAnchor.constraint(equalToConstant: 362).isActive = true

        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        if showsSpinner {
            let indicator = NSProgressIndicator()
            indicator.style = .spinning
            indicator.controlSize = .small
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.widthAnchor.constraint(equalToConstant: 14).isActive = true
            indicator.startAnimation(nil)
            contentStack.addArrangedSubview(indicator)
        } else if let systemImageName {
            let imageView = NSImageView()
            imageView.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: title)
            imageView.symbolConfiguration = .init(pointSize: 12, weight: .regular)
            imageView.contentTintColor = .secondaryLabelColor
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 14).isActive = true
            contentStack.addArrangedSubview(imageView)
        }

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13, weight: fontWeight)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        contentStack.addArrangedSubview(titleLabel)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentStack.addArrangedSubview(spacer)

        if let accessory {
            accessoryLabel.stringValue = accessory
            accessoryLabel.font = .systemFont(ofSize: 13, weight: .medium)
            accessoryLabel.textColor = .tertiaryLabelColor
            accessoryLabel.setContentHuggingPriority(.required, for: .horizontal)
            contentStack.addArrangedSubview(accessoryLabel)
        }

        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateEnabledState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isEnabled: Bool {
        didSet {
            updateEnabledState()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else {
            return
        }

        isHovering = true
        updateBackground()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateBackground()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }

        sendAction(action, to: target)
    }

    private func updateEnabledState() {
        alphaValue = isEnabled ? 1 : 0.45
        updateBackground()
    }

    private func updateBackground() {
        layer?.backgroundColor = isHovering && isEnabled
            ? NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            : NSColor.clear.cgColor
    }
}
