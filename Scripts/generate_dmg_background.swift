#!/usr/bin/env swift

import AppKit

/// 8 桁 / 6 桁の HEX 文字列を NSColor へ変換する。
func color(hex: String) -> NSColor {
  let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  var value: UInt64 = 0
  Scanner(string: sanitized).scanHexInt64(&value)

  switch sanitized.count {
  case 6:
    return NSColor(
      red: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
  case 8:
    return NSColor(
      red: CGFloat((value >> 24) & 0xFF) / 255,
      green: CGFloat((value >> 16) & 0xFF) / 255,
      blue: CGFloat((value >> 8) & 0xFF) / 255,
      alpha: CGFloat(value & 0xFF) / 255
    )
  default:
    return .black
  }
}

/// 上端基準の座標を AppKit の矩形へ変換する。
func rectFromTop(canvasHeight: CGFloat, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
  NSRect(x: x, y: canvasHeight - y - height, width: width, height: height)
}

/// 角丸矩形を塗りと線で描画する。
func drawRoundedRect(
  canvasHeight: CGFloat,
  x: CGFloat,
  y: CGFloat,
  width: CGFloat,
  height: CGFloat,
  radius: CGFloat,
  fillColor: NSColor,
  strokeColor: NSColor? = nil,
  lineWidth: CGFloat = 1
) {
  let rect = rectFromTop(canvasHeight: canvasHeight, x: x, y: y, width: width, height: height)
  let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

  fillColor.setFill()
  path.fill()

  if let strokeColor {
    strokeColor.setStroke()
    path.lineWidth = lineWidth
    path.stroke()
  }
}

/// テキストを中央寄せまたは任意幅で描画する。
func drawText(
  _ text: String,
  canvasHeight: CGFloat,
  x: CGFloat,
  y: CGFloat,
  width: CGFloat,
  font: NSFont,
  color: NSColor,
  alignment: NSTextAlignment = .center,
  lineHeightMultiple: CGFloat = 1
) {
  let paragraphStyle = NSMutableParagraphStyle()
  paragraphStyle.alignment = alignment
  paragraphStyle.lineBreakMode = .byWordWrapping
  paragraphStyle.lineHeightMultiple = lineHeightMultiple

  let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: color,
    .paragraphStyle: paragraphStyle,
  ]
  let attributed = NSAttributedString(string: text, attributes: attributes)
  let bounds = attributed.boundingRect(
    with: NSSize(width: width, height: .greatestFiniteMagnitude),
    options: [.usesLineFragmentOrigin, .usesFontLeading]
  )
  let rect = rectFromTop(
    canvasHeight: canvasHeight,
    x: x,
    y: y,
    width: width,
    height: ceil(bounds.height)
  )
  attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

/// Finder の DMG 背景を生成する。
func generateBackground(outputPath: String, appName: String) throws {
  let logicalSize = NSSize(width: 980, height: 497)
  let contentYOffset: CGFloat = 75
  let scale: CGFloat = 2

  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(logicalSize.width * scale),
    pixelsHigh: Int(logicalSize.height * scale),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else {
    throw NSError(domain: "DMGBackground", code: 1, userInfo: [NSLocalizedDescriptionKey: "bitmap の初期化に失敗しました。"])
  }

  rep.size = logicalSize

  guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    throw NSError(domain: "DMGBackground", code: 2, userInfo: [NSLocalizedDescriptionKey: "graphics context の初期化に失敗しました。"])
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  defer { NSGraphicsContext.restoreGraphicsState() }

  let canvasRect = NSRect(origin: .zero, size: logicalSize)
  let gradient = NSGradient(
    colors: [
      color(hex: "#161B24"),
      color(hex: "#23283A"),
      color(hex: "#2F2443"),
      color(hex: "#1A2030"),
    ],
    atLocations: [0.0, 0.38, 0.72, 1.0],
    colorSpace: .deviceRGB
  )
  gradient?.draw(in: canvasRect, angle: 120)

  let headlineFont = NSFont.systemFont(ofSize: 32, weight: .bold)
  let bodyFont = NSFont.systemFont(ofSize: 15, weight: .medium)
  let arrowFont = NSFont.systemFont(ofSize: 32, weight: .bold)

  drawText(
    "Install \(appName)",
    canvasHeight: logicalSize.height,
    x: 300,
    y: 66 + contentYOffset,
    width: 380,
    font: headlineFont,
    color: color(hex: "#F3F5F9")
  )

  let shadow = NSShadow()
  shadow.shadowColor = color(hex: "#00000033")
  shadow.shadowBlurRadius = 28
  shadow.shadowOffset = NSSize(width: 0, height: -10)
  shadow.set()
  drawRoundedRect(
    canvasHeight: logicalSize.height,
    x: 454,
    y: 145 + contentYOffset,
    width: 72,
    height: 72,
    radius: 36,
    fillColor: color(hex: "#7C3AED26"),
    strokeColor: color(hex: "#A78BFA55"),
    lineWidth: 1
  )
  NSShadow().set()

  drawText(
    "→",
    canvasHeight: logicalSize.height,
    x: 454,
    y: 160 + contentYOffset,
    width: 72,
    font: arrowFont,
    color: color(hex: "#F4EFFF")
  )

  drawText(
    "Drag \(appName) into Applications, then launch it from your Applications folder.",
    canvasHeight: logicalSize.height,
    x: 292,
    y: 238 + contentYOffset,
    width: 396,
    font: bodyFont,
    color: color(hex: "#D0D4DE"),
    lineHeightMultiple: 1.5
  )

  guard let pngData = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "DMGBackground", code: 3, userInfo: [NSLocalizedDescriptionKey: "PNG 変換に失敗しました。"])
  }

  let fileURL = URL(fileURLWithPath: outputPath)
  try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
  try pngData.write(to: fileURL)
}

/// コマンドライン引数から出力先とアプリ名を決めて背景生成を実行する。
func main() throws {
  let arguments = CommandLine.arguments
  guard arguments.count == 3 else {
    throw NSError(
      domain: "DMGBackground",
      code: 4,
      userInfo: [NSLocalizedDescriptionKey: "Usage: generate_dmg_background.swift <output-path> <app-name>"]
    )
  }

  try generateBackground(outputPath: arguments[1], appName: arguments[2])
}

do {
  try main()
} catch {
  fputs("ERROR: \(error.localizedDescription)\n", stderr)
  exit(1)
}
