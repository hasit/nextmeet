import AppKit
import Foundation

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? fileManager.currentDirectoryPath)
let assetsURL = rootURL.appendingPathComponent("Assets", isDirectory: true)
let icnsURL = assetsURL.appendingPathComponent("AppIcon.icns")
let previewURL = assetsURL.appendingPathComponent("AppIconPreview.png")

try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)

let iconRepresentations: [(type: String, pixels: Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024)
]

var chunks: [(type: String, data: Data)] = []
for representation in iconRepresentations {
    chunks.append((representation.type, try pngData(pixelSize: representation.pixels)))
}

try pngData(pixelSize: 1024).write(to: previewURL)
try writeICNS(chunks: chunks, to: icnsURL)

print("Generated \(icnsURL.path)")

func pngData(pixelSize: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.couldNotCreateBitmap
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconGenerationError.couldNotCreateContext
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    graphicsContext.shouldAntialias = true
    graphicsContext.cgContext.scaleBy(x: CGFloat(pixelSize) / 1024, y: CGFloat(pixelSize) / 1024)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [.compressionFactor: 0.9]) else {
        throw IconGenerationError.couldNotEncodePNG
    }

    return data
}

func drawIcon() {
    drawBackground()
    drawCalendarTile()
    drawJoinArrow()
}

func drawBackground() {
    let backgroundPath = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 214, yRadius: 214)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha: 0.34)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    color(0x182132).setFill()
    backgroundPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        color(0x263247),
        color(0x111827)
    ])?.draw(in: backgroundPath, angle: 92)

    color(0xFFFFFF, alpha: 0.10).setStroke()
    backgroundPath.lineWidth = 5
    backgroundPath.stroke()
}

func drawCalendarTile() {
    let frame = NSRect(x: 218, y: 184, width: 588, height: 656)
    let tilePath = NSBezierPath(roundedRect: frame, xRadius: 76, yRadius: 76)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, alpha: 0.24)
    shadow.shadowBlurRadius = 26
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0xF7FAFC).setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()

    let headerFrame = NSRect(x: frame.minX, y: frame.maxY - 178, width: frame.width, height: 178)
    NSGradient(colors: [
        color(0x2DD4BF),
        color(0x0A84FF)
    ])?.draw(in: headerFrame, angle: 0)

    color(0xFFFFFF, alpha: 0.88).setFill()
    circle(center: CGPoint(x: frame.minX + 146, y: frame.maxY - 88), radius: 22).fill()
    circle(center: CGPoint(x: frame.maxX - 146, y: frame.maxY - 88), radius: 22).fill()

    color(0xD7DEE8).setFill()
    roundedRect(x: 292, y: 558, width: 320, height: 34, radius: 17).fill()

    color(0xD9F4F1).setFill()
    roundedRect(x: 292, y: 472, width: 378, height: 44, radius: 22).fill()

    color(0x0A84FF, alpha: 0.92).setFill()
    roundedRect(x: 292, y: 472, width: 78, height: 44, radius: 22).fill()

    color(0xD7DEE8).setFill()
    roundedRect(x: 292, y: 386, width: 274, height: 34, radius: 17).fill()
    roundedRect(x: 292, y: 314, width: 336, height: 34, radius: 17).fill()

    NSGraphicsContext.restoreGraphicsState()

    color(0xFFFFFF, alpha: 0.70).setStroke()
    tilePath.lineWidth = 4
    tilePath.stroke()
}

func drawJoinArrow() {
    let start = CGPoint(x: 336, y: 316)
    let tip = CGPoint(x: 760, y: 740)
    let base = CGPoint(x: 656, y: 636)
    let left = CGPoint(x: 582, y: 714)
    let right = CGPoint(x: 732, y: 562)

    let outline = NSBezierPath()
    outline.move(to: start)
    outline.line(to: base)
    outline.lineWidth = 98
    outline.lineCapStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x063B74, alpha: 0.34)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -7)
    shadow.set()
    color(0xFFFFFF, alpha: 0.88).setStroke()
    outline.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let shaft = NSBezierPath()
    shaft.move(to: start)
    shaft.line(to: base)
    shaft.lineWidth = 72
    shaft.lineCapStyle = .round

    NSGraphicsContext.saveGraphicsState()
    let shaftShadow = NSShadow()
    shaftShadow.shadowColor = color(0x063B74, alpha: 0.35)
    shaftShadow.shadowBlurRadius = 16
    shaftShadow.shadowOffset = NSSize(width: 0, height: -6)
    shaftShadow.set()
    color(0x0A84FF).setStroke()
    shaft.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let headOutline = NSBezierPath()
    headOutline.move(to: tip)
    headOutline.line(to: left)
    headOutline.line(to: right)
    headOutline.close()
    color(0xFFFFFF, alpha: 0.88).setFill()
    headOutline.fill()

    let head = NSBezierPath()
    head.move(to: tip)
    head.line(to: CGPoint(x: 604, y: 702))
    head.line(to: CGPoint(x: 720, y: 584))
    head.close()
    color(0x0A84FF).setFill()
    head.fill()
}

func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

func circle(center: CGPoint, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func writeICNS(chunks: [(type: String, data: Data)], to outputURL: URL) throws {
    let totalLength = 8 + chunks.reduce(0) { partialResult, chunk in
        partialResult + 8 + chunk.data.count
    }

    guard totalLength <= Int(UInt32.max) else {
        throw IconGenerationError.icnsTooLarge
    }

    var output = Data()
    output.appendASCII("icns")
    output.appendUInt32BE(UInt32(totalLength))

    for chunk in chunks {
        guard chunk.type.utf8.count == 4 else {
            throw IconGenerationError.invalidICNSType(chunk.type)
        }

        output.appendASCII(chunk.type)
        output.appendUInt32BE(UInt32(chunk.data.count + 8))
        output.append(chunk.data)
    }

    try output.write(to: outputURL)
}

extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }
}

enum IconGenerationError: LocalizedError {
    case couldNotCreateBitmap
    case couldNotCreateContext
    case couldNotEncodePNG
    case invalidICNSType(String)
    case icnsTooLarge

    var errorDescription: String? {
        switch self {
        case .couldNotCreateBitmap:
            return "Could not create bitmap for app icon."
        case .couldNotCreateContext:
            return "Could not create graphics context for app icon."
        case .couldNotEncodePNG:
            return "Could not encode app icon PNG."
        case .invalidICNSType(let type):
            return "Invalid ICNS representation type: \(type)."
        case .icnsTooLarge:
            return "Generated ICNS file is too large."
        }
    }
}
