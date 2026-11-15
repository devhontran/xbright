import AppKit

final class SliderRow: NSView {
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let valueLabel = NSTextField(labelWithString: "")
    var onChange: ((Int) -> Void)?

    init(name: String, percent: Int) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 52))
        let title = NSTextField(labelWithString: name)
        title.frame = NSRect(x: 16, y: 28, width: 178, height: 18)
        title.lineBreakMode = .byTruncatingTail
        valueLabel.frame = NSRect(x: 194, y: 28, width: 50, height: 18)
        valueLabel.alignment = .right
        valueLabel.textColor = .secondaryLabelColor
        slider.frame = NSRect(x: 14, y: 4, width: 232, height: 22)
        slider.target = self
        slider.action = #selector(changed)
        addSubview(title)
        addSubview(valueLabel)
        addSubview(slider)
        show(percent)
    }

    required init?(coder: NSCoder) { nil }

    func show(_ percent: Int) {
        slider.integerValue = percent
        valueLabel.stringValue = "\(percent)%"
    }

    @objc private func changed() {
        valueLabel.stringValue = "\(slider.integerValue)%"
        onChange?(slider.integerValue)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let keysItem = NSMenuItem(title: L("Phím độ sáng F1/F2", "Brightness keys F1/F2"), action: #selector(toggleKeys), keyEquivalent: "")
    private var displays: [Display] = []
    private var rows: [String: SliderRow] = [:]
    private var keys: BrightnessKeys!
    private var pendingReload: DispatchWorkItem?
    private var trustTimer: Timer?
    private let keyStep = 5

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: "XBright")
        statusItem.menu = menu
        menu.delegate = self
        keysItem.target = self

        keys = BrightnessKeys(
            hasTarget: { [unowned self] in self.displayUnderCursor() != nil },
            step: { [unowned self] direction in self.step(direction) }
        )
        keys.start()

        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(displaysChanged), name: NSWorkspace.didWakeNotification, object: nil)

        rebuildMenu()
        reload()
    }

    func menuWillOpen(_ menu: NSMenu) {
        keysItem.state = keys.isActive ? .on : .off
        reload()
    }

    // A monitor ignores DDC for a moment after hot-plug or wake, so the re-scan waits.
    @objc private func displaysChanged() {
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reload() }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func reload() {
        DDC.queue.async {
            let found = DDC.enumerate()
            DispatchQueue.main.async { self.apply(Display.resolve(found)) }
        }
    }

    private func apply(_ fresh: [Display]) {
        guard fresh.map(\.key) == displays.map(\.key) else {
            displays = fresh
            rebuildMenu()
            return
        }
        for (current, update) in zip(displays, fresh) {
            current.adopt(update)
            rows[current.key]?.show(current.percent)
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        rows = [:]
        if displays.isEmpty {
            let empty = NSMenuItem(title: L("Không thấy màn hình hỗ trợ DDC", "No DDC-capable display found"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for display in displays {
            let row = SliderRow(name: display.name, percent: display.percent)
            row.onChange = { display.set($0) }
            rows[display.key] = row
            let item = NSMenuItem()
            item.view = row
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(keysItem)
        menu.addItem(.separator())
        let support = NSMenuItem(title: L("Ủng hộ tác giả ☕", "Buy me a coffee ☕"), action: #selector(openSupport), keyEquivalent: "")
        support.target = self
        menu.addItem(support)
        menu.addItem(NSMenuItem(title: L("Thoát XBright", "Quit XBright"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func displayUnderCursor() -> Display? {
        let point = NSEvent.mouseLocation
        let id = NSScreen.screens.first { $0.frame.contains(point) }?.displayID
        return displays.first { $0.displayID != nil && $0.displayID == id } ?? (displays.count == 1 ? displays[0] : nil)
    }

    private func step(_ direction: Int) {
        guard let display = displayUnderCursor() else { return }
        display.set(display.percent + direction * keyStep)
        rows[display.key]?.show(display.percent)
    }

    @objc private func openSupport() {
        NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/devhontran")!)
    }

    @objc private func toggleKeys() {
        if keys.isActive {
            keys.stop()
            return
        }
        guard !keys.start() else { return }
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        trustTimer?.invalidate()
        var attempts = 0
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            attempts += 1
            if self?.keys.start() == true || attempts > 90 { timer.invalidate() }
        }
    }
}
