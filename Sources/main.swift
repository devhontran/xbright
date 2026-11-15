import AppKit

func runCLI(_ arguments: [String]) -> Int32 {
    let found = DDC.enumerate()
    switch arguments.first {
    case "get":
        for (index, display) in found.enumerated() {
            print("\(index)\t\(display.percent)%\t\(display.edidName ?? "-")")
        }
        return 0
    case "set":
        guard arguments.count >= 2, let percent = Int(arguments[1]), (0...100).contains(percent) else { break }
        let targets = arguments.count >= 3 ? Int(arguments[2]).flatMap { found.indices.contains($0) ? [found[$0]] : nil } : found
        guard let targets else { break }
        for display in targets {
            DDC.write(display.service, percent: percent, maxValue: display.maxValue)
        }
        return 0
    default:
        break
    }
    FileHandle.standardError.write(Data("usage: XBright get | set <0-100> [display-index]\n".utf8))
    return 64
}

let arguments = Array(CommandLine.arguments.dropFirst())
if !arguments.isEmpty {
    exit(runCLI(arguments))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
