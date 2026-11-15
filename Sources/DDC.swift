import CoreGraphics
import Foundation
import IOKit

@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(_ service: CFTypeRef, _ chip: UInt32, _ offset: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn
@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chip: UInt32, _ address: UInt32, _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

struct DDCDisplay {
    let service: CFTypeRef
    let vendor: UInt32
    let product: UInt32
    let serial: UInt32
    let edidName: String?
    let percent: Int
    let maxValue: Int
}

enum DDC {
    static let queue = DispatchQueue(label: "dev.hontran.xbright.ddc")

    private static let brightness: UInt8 = 0x10
    // DDC/CI timing: the monitor needs >= 40 ms before a reply is readable and 50 ms between commands.
    private static let settle: useconds_t = 50_000

    static func enumerate() -> [DDCDisplay] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var found: [DDCDisplay] = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let location = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            guard location == "External",
                  let service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue(),
                  let value = read(service) else { continue }

            var edid = [UInt8](repeating: 0, count: 128)
            let hasEDID = IOAVServiceReadI2C(service, 0x50, 0, &edid, 128) == KERN_SUCCESS
                && Array(edid[0..<8]) == [0, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0]
            found.append(DDCDisplay(
                service: service,
                vendor: hasEDID ? UInt32(edid[8]) << 8 | UInt32(edid[9]) : 0,
                product: hasEDID ? UInt32(edid[11]) << 8 | UInt32(edid[10]) : 0,
                serial: hasEDID ? edid[12..<16].reversed().reduce(0) { $0 << 8 | UInt32($1) } : 0,
                edidName: hasEDID ? name(in: edid) : nil,
                percent: Int((Double(value.current) * 100 / Double(value.max)).rounded()),
                maxValue: value.max
            ))
        }
        return found
    }

    static func read(_ service: CFTypeRef) -> (current: Int, max: Int)? {
        for _ in 0..<4 {
            var packet: [UInt8] = [0x82, 0x01, brightness, 0]
            packet[3] = 0x6E ^ 0x51 ^ packet[0] ^ packet[1] ^ packet[2]
            var reply = [UInt8](repeating: 0, count: 11)
            guard IOAVServiceWriteI2C(service, 0x37, 0x51, &packet, UInt32(packet.count)) == KERN_SUCCESS else { usleep(settle); continue }
            usleep(settle)
            guard IOAVServiceReadI2C(service, 0x37, 0x51, &reply, 11) == KERN_SUCCESS else { usleep(settle); continue }
            let checksum = reply[0..<10].reduce(UInt8(0x50)) { $0 ^ $1 }
            let max = Int(reply[6]) << 8 | Int(reply[7])
            if checksum == reply[10], reply[2] == 0x02, reply[3] == 0, reply[4] == brightness, max > 0 {
                return (Int(reply[8]) << 8 | Int(reply[9]), max)
            }
            usleep(settle)
        }
        return nil
    }

    static func write(_ service: CFTypeRef, percent: Int, maxValue: Int) {
        let value = Int((Double(percent) * Double(maxValue) / 100).rounded())
        var packet: [UInt8] = [0x84, 0x03, brightness, UInt8(value >> 8), UInt8(value & 0xff), 0]
        packet[5] = 0x6E ^ 0x51 ^ packet[0] ^ packet[1] ^ packet[2] ^ packet[3] ^ packet[4]
        // Sent twice: a single write is occasionally dropped by the monitor without an error.
        for _ in 0..<2 {
            _ = IOAVServiceWriteI2C(service, 0x37, 0x51, &packet, UInt32(packet.count))
            usleep(settle)
        }
    }

    private static func name(in edid: [UInt8]) -> String? {
        for offset in stride(from: 54, to: 126, by: 18) where edid[offset] == 0 && edid[offset + 1] == 0 && edid[offset + 3] == 0xfc {
            let text = String(decoding: edid[(offset + 5)..<(offset + 18)].filter { (0x20...0x7e).contains($0) }, as: UTF8.self)
                .trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { return text }
        }
        return nil
    }
}
