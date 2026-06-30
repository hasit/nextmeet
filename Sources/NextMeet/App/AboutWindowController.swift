import AppKit

@MainActor
final class AboutWindowController: NSWindowController {
    private let metadata: AppMetadata

    init(metadata: AppMetadata = .current) {
        self.metadata = metadata

        let contentView = NSVisualEffectView()
        contentView.material = .contentBackground
        contentView.state = .active

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About NextMeet"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = contentView

        super.init(window: window)

        buildContent(in: contentView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        guard let window else {
            return
        }

        if window.isVisible == false {
            window.center()
        }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildContent(in contentView: NSView) {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 74),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -34)
        ])

        stack.addArrangedSubview(appIconView())
        stack.addArrangedSubview(titleLabel())
        let description = descriptionLabel()
        stack.addArrangedSubview(description)
        stack.setCustomSpacing(28, after: description)

        let details = detailsStack()
        stack.addArrangedSubview(details)
        stack.setCustomSpacing(28, after: details)

        stack.addArrangedSubview(buttonStack())
    }

    private func appIconView() -> NSImageView {
        let imageView = NSImageView()
        imageView.image = NSApplication.shared.applicationIconImage
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 112),
            imageView.heightAnchor.constraint(equalToConstant: 112)
        ])

        return imageView
    }

    private func titleLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "NextMeet")
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.alignment = .center
        label.textColor = .labelColor
        return label
    }

    private func descriptionLabel() -> NSTextField {
        let label = NSTextField(
            wrappingLabelWithString: "Today's meeting links, right in your menu bar."
        )
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 2
        return label
    }

    private func detailsStack() -> NSStackView {
        let rows = [
            detailRow(title: "Version", value: metadata.version),
            detailRow(title: "Build", value: metadata.build),
            detailRow(title: "Commit", value: metadata.shortCommit, valueColor: .linkColor)
        ]

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        return stack
    }

    private func detailRow(title: String, value: String, valueColor: NSColor = .secondaryLabelColor) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .right
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 72).isActive = true

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        valueLabel.textColor = valueColor
        valueLabel.alignment = .left
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 118).isActive = true

        let stack = NSStackView(views: [titleLabel, valueLabel])
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 14
        return stack
    }

    private func buttonStack() -> NSStackView {
        let stack = NSStackView(views: [
            button(title: "GitHub", action: #selector(openGitHub)),
            button(title: "Releases", action: #selector(openReleases))
        ])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        return stack
    }

    private func button(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = .systemFont(ofSize: 14, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 104).isActive = true
        return button
    }

    @objc private func openGitHub() {
        openURL("https://github.com/hasit/nextmeet")
    }

    @objc private func openReleases() {
        openURL("https://github.com/hasit/nextmeet/releases")
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
