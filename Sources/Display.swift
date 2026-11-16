import AppKit

final class Display {
    let key: String
    let displayID: CGDirectDisplayID?
    let name: String
    private(set) var service: CFTypeRef
    private(set) var maxValue: Int
    private(set) var percent: Int
    private var pending: Int?
    private var writing = false

    init(key: String, displayID: CGDirectDisplayID?, name: String, service: CFTypeRef, maxValue: Int, percent: Int) {
        self.key = key
        self.displayID = displayID
        self.name = name
        self.service = service
        self.maxValue = maxValue
        self.percent = percent
    }

    func set(_ value: Int) {
        percent = min(100, max(0, value))
        pending = percent
        if !writing { drain() }
    }

    func adopt(_ fresh: Display) {
        service = fresh.service
        maxValue = fresh.maxValue
        if !writing { percent = fresh.percent }
    }

    private func drain() {
        guard let value = pending else {
            writing = false
            return
        }
        pending = nil
        writing = true
        let service = self.service
        let maxValue = self.maxValue
        DDC.queue.async {
            DDC.write(service, percent: value, maxValue: maxValue)
            DispatchQueue.main.async { self.drain() }
        }
    }

    static func resolve(_ found: [DDCDisplay]) -> [Display] {
        var free: [(id: CGDirectDisplayID, name: String)] = NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID, CGDisplayIsBuiltin(id) == 0 else { return nil }
            return (id, screen.localizedName)
        }
        return found.enumerated().map { index, ddc in
            let exact = free.firstIndex {
                CGDisplayVendorNumber($0.id) == ddc.vendor && CGDisplayModelNumber($0.id) == ddc.product && CGDisplaySerialNumber($0.id) == ddc.serial
            }
            let loose = free.firstIndex {
                CGDisplayVendorNumber($0.id) == ddc.vendor && CGDisplayModelNumber($0.id) == ddc.product
            }
            let screen = (exact ?? loose).map { free.remove(at: $0) }
            return Display(
                key: "\(ddc.vendor)-\(ddc.product)-\(ddc.serial)-\(index)",
                displayID: screen?.id,
                name: [ddc.edidName, screen?.name].compactMap { $0 }.first { !$0.isEmpty } ?? L("Màn hình \(index + 1)", "Display \(index + 1)"),
                service: ddc.service,
                maxValue: ddc.maxValue,
                percent: ddc.percent
            )
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
