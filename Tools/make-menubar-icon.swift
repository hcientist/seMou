import AppKit
import CoreImage

// Converts black-on-white line art into the menu bar template image: background becomes
// transparent, lines are thickened so they survive scaling down to 18pt, and the drawing is
// cropped square. Run from the repo root:
//   swift Tools/make-menubar-icon.swift semou-menubar-icon.png Resources/Assets.xcassets/MenuBarIcon.imageset 14
let args = CommandLine.arguments
let src = CIImage(contentsOf: URL(fileURLWithPath: args[1]))!
let outDir = args[2]
let radius = args.count > 3 ? Double(args[3])! : 14
let ci = CIContext()

// Dark lines → white, thicken, then use brightness as alpha.
var img = src.applyingFilter("CIColorInvert")
// Push near-white background noise to fully transparent: v' = 1.6v - 0.35, clamped.
let gain = CIVector(x: 1.6, y: 0, z: 0, w: 0)
img = img.applyingFilter("CIColorMatrix", parameters: [
    "inputRVector": gain, "inputGVector": CIVector(x: 0, y: 1.6, z: 0, w: 0), "inputBVector": CIVector(x: 0, y: 0, z: 1.6, w: 0),
    "inputBiasVector": CIVector(x: -0.35, y: -0.35, z: -0.35, w: 0),
]).applyingFilter("CIColorClamp")
img = img.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": radius])
img = img.applyingFilter("CIMaskToAlpha")
img = img.applyingFilter("CIColorMatrix", parameters: [
    "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
    "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
]).cropped(to: src.extent)

// Bounding box of the drawing.
let full = ci.createCGImage(img, from: src.extent)!
let rep = NSBitmapImageRep(cgImage: full)
var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
for y in stride(from: 0, to: rep.pixelsHigh, by: 2) { for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
    if rep.colorAt(x: x, y: y)!.alphaComponent > 0.2 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
}}
let side = max(maxX - minX, maxY - minY) + 8
let crop = CGRect(x: (minX + maxX - side) / 2, y: (minY + maxY - side) / 2, width: side, height: side) // top-left origin
let cropped = full.cropping(to: crop)!

func write(_ px: Int, _ name: String) {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: px, height: px))
    let out = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
write(18, "menubar.png")
write(36, "menubar@2x.png")
