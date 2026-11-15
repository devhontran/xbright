import AppKit

final class BrightnessKeys {
    private let hasTarget: () -> Bool
    private let step: (Int) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isActive: Bool { tap != nil }

    init(hasTarget: @escaping () -> Bool, step: @escaping (Int) -> Void) {
        self.hasTarget = hasTarget
        self.step = step
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard AXIsProcessTrusted(),
              let port = CGEvent.tapCreate(
                  tap: .cgSessionEventTap,
                  place: .headInsertEventTap,
                  options: .defaultTap,
                  eventsOfInterest: CGEventMask(1) << systemDefined,
                  callback: brightnessKeysCallback,
                  userInfo: Unmanaged.passUnretained(self).toOpaque()
              ) else { return false }
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        tap = port
        source = runLoopSource
        return true
    }

    func stop() {
        guard let port = tap else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        tap = nil
        source = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
            return false
        }
        guard type.rawValue == systemDefined,
              let key = NSEvent(cgEvent: event), key.subtype.rawValue == mediaKeySubtype else { return false }
        let code = (key.data1 & 0xFFFF0000) >> 16
        guard code == brightnessUp || code == brightnessDown, hasTarget() else { return false }
        if (key.data1 & 0xFF00) >> 8 == keyDown {
            step(code == brightnessUp ? 1 : -1)
        }
        return true
    }
}

// IOKit/hidsystem constants that Swift does not import: NX_SYSDEFINED, NX_SUBTYPE_AUX_CONTROL_BUTTONS,
// NX_KEYTYPE_BRIGHTNESS_UP/DOWN, NX_KEYDOWN.
private let systemDefined: UInt32 = 14
private let mediaKeySubtype: Int16 = 8
private let brightnessUp = 2
private let brightnessDown = 3
private let keyDown = 0xA

private func brightnessKeysCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let keys = Unmanaged<BrightnessKeys>.fromOpaque(refcon).takeUnretainedValue()
    return keys.handle(type, event) ? nil : Unmanaged.passUnretained(event)
}
