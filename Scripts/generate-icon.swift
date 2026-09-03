import AppKit

guard CommandLine.arguments.count == 3,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else { exit(1) }

let destination = URL(fileURLWithPath: CommandLine.arguments[2])
let iconset = destination.deletingLastPathComponent().appendingPathComponent("ConnectBar.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ pixels: Int, name: String) throws {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSBezierPath(ovalIn: NSRect(origin: .zero, size: size).insetBy(dx: size.width * 0.045, dy: size.height * 0.045)).addClip()
    source.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
    image.unlockFocus()

    guard let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data),
          let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    try png.write(to: iconset.appendingPathComponent(name))
}

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    try render(points * scale, name: "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png")
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
try process.run()
process.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
