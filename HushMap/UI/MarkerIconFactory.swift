import UIKit
import CoreGraphics

// MARK: - Report Status
enum ReportStatus {
    case quiet
    case moderate
    case noisy
}

// App palette locked to sRGB (fixed, not dynamic)
enum HushPalette {
    static let green = UIColor(red: 0.12, green: 0.74, blue: 0.47, alpha: 1.0) // #1FCB78
    static let red   = UIColor(red: 0.90, green: 0.29, blue: 0.32, alpha: 1.0) // #E54A52

    // Amber tuned to stay yellow after Google's darkening gradient.
    // Try these (from less to more yellow): A, B, C.
    static let amberA = UIColor(red: 1.00, green: 0.81, blue: 0.24, alpha: 1.0) // #FFC83D
    static let amberB = UIColor(red: 1.00, green: 0.86, blue: 0.24, alpha: 1.0) // #FFDB3D
    static let amberC = UIColor(red: 1.00, green: 0.92, blue: 0.00, alpha: 1.0) // #FFEA00
}

// Force sRGB before handing to Google (prevents P3/dynamic drift)
extension UIColor {
    func resolvedSRGB(for trait: UITraitEnvironment) -> UIColor {
        let fixed = self.resolvedColor(with: trait.traitCollection) // resolve dynamic colors
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if fixed.getRed(&r, green: &g, blue: &b, alpha: &a) { return UIColor(red: r, green: g, blue: b, alpha: a) }
        return fixed // fallback
    }
}

extension ReportStatus {
    var color: UIColor {
        switch self {
        case .quiet:    return HushPalette.green
        case .moderate: return HushPalette.amberB   // start with B; bump to C if still brown
        case .noisy:    return HushPalette.red
        }
    }
    var selectedColor: UIColor { 
        // Use slightly brighter versions instead of alpha to preserve white center dot
        switch self {
        case .quiet:    return UIColor(red: 0.20, green: 0.82, blue: 0.55, alpha: 1) // brighter green
        case .moderate: return HushPalette.amberB // Use same amber for selected to avoid further complications
        case .noisy:    return UIColor(red: 0.95, green: 0.36, blue: 0.40, alpha: 1) // brighter red
        }
    }
}

// MARK: - Pin Sizing Configuration
struct PinSizing {
    static let minZoom: Float = 11    // start shrinking below this
    static let maxZoom: Float = 17    // start growing above this
    static let growPct: CGFloat = 0.15 // ±15% range
    
    // Returns 0.85–1.15 multiplier across min→max range
    static func sizeMultiplier(for zoom: Float) -> CGFloat {
        let clampedZoom = max(minZoom, min(maxZoom, zoom))
        let normalizedZoom = CGFloat(clampedZoom - minZoom) / CGFloat(maxZoom - minZoom)
        return 0.85 + (normalizedZoom * growPct * 2) // 0.85 to 1.15
    }
    
    // Quantize multiplier to 0.05 steps for cache efficiency
    static func quantizedMultiplier(for zoom: Float) -> CGFloat {
        let multiplier = sizeMultiplier(for: zoom)
        return round(multiplier / 0.05) * 0.05
    }
}

// MARK: - Marker Size
enum MarkerSize {
    case normal
    case selected

    var pointSize: CGFloat { self == .normal ? 32 : 40 }
    var strokeWidth: CGFloat { 2 }
    var haloWidth: CGFloat { 3 }
}

// MARK: - Recency Stroke (for Quick Update indicator)
enum RecencyStroke {
    case none
    case quiet
    case noisy

    var color: UIColor? {
        switch self {
        case .none: return nil
        case .quiet: return UIColor(red: 0.36, green: 0.66, blue: 0.49, alpha: 1.0)  // Muted green #5BA87C
        case .noisy: return UIColor(red: 0.83, green: 0.52, blue: 0.35, alpha: 1.0)  // Muted orange #D4845A
        }
    }
}

// MARK: - Color Palette
struct MarkerPalette {
    static let quiet = HushPalette.green
    static let amber = HushPalette.amberB
    static let noisy = HushPalette.red
    static let stroke = UIColor.white
    static let shadow = UIColor.black.withAlphaComponent(0.22)
    
    // Adaptive halo colors based on interface style
    static func haloColor(for interfaceStyle: UIUserInterfaceStyle) -> UIColor {
        interfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.65)
                                : UIColor.white.withAlphaComponent(0.80)
    }
}

// MARK: - Marker Icon Factory
final class MarkerIconFactory {
    static let shared = MarkerIconFactory()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 50 // Reasonable limit for marker variants
    }
    
    func image(for status: ReportStatus, size: MarkerSize, selected: Bool, scale: CGFloat, zoomMultiplier: CGFloat = 1.0, interfaceStyle: UIUserInterfaceStyle = .light, recencyStroke: RecencyStroke = .none) -> UIImage {
        let quantizedMultiplier = round(zoomMultiplier / 0.05) * 0.05
        let styleKey = interfaceStyle == .dark ? "dark" : "light"
        let recencyKey = recencyStroke == .none ? "" : "-recency\(recencyStroke)"
        let cacheKey = "pin-\(status)-\(size)-\(selected)-@\(Int(scale))-\(String(format: "%.2f", quantizedMultiplier))-\(styleKey)\(recencyKey)" as NSString

        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let image = drawTeardropMarker(status: status, size: size, scale: scale, zoomMultiplier: zoomMultiplier, interfaceStyle: interfaceStyle, recencyStroke: recencyStroke)
        cache.setObject(image, forKey: cacheKey)
        return image
    }
    
    private func drawTeardropMarker(status: ReportStatus, size: MarkerSize, scale: CGFloat, zoomMultiplier: CGFloat, interfaceStyle: UIUserInterfaceStyle, recencyStroke: RecencyStroke = .none) -> UIImage {
        let S = size.pointSize * zoomMultiplier

        // Canvas with padding for halo and recency stroke
        let padding: CGFloat = 8
        let canvasSize = CGSize(width: S + padding * 2, height: S + padding * 2)

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in
            let c = ctx.cgContext
            c.saveGState()

            // Translate to account for padding
            c.translateBy(x: padding, y: padding)

            // Geometry
            let tipY = S - 0.5                   // snap to pixel
            let bulbCenter = CGPoint(x: S * 0.5, y: S * 0.44)
            let bulbR = S * 0.34                 // top bulb radius
            let holeR = S * 0.24                 // inner hole radius

            // Outer teardrop path
            let path = UIBezierPath()
            // Arc across top bulb (approx 210° → -30°)
            path.addArc(withCenter: bulbCenter, radius: bulbR,
                       startAngle: CGFloat.pi * 1.15, endAngle: CGFloat.pi * -0.15, clockwise: true)
            // Right curve to tip
            path.addQuadCurve(to: CGPoint(x: S * 0.50, y: tipY),
                             controlPoint: CGPoint(x: S * 0.86, y: S * 0.86))
            // Left curve back to arc start
            let leftArcEnd = CGPoint(x: bulbCenter.x - bulbR * cos(.pi * 0.15),
                                    y: bulbCenter.y + bulbR * sin(.pi * 0.15))
            path.addQuadCurve(to: leftArcEnd,
                             controlPoint: CGPoint(x: S * 0.14, y: S * 0.86))
            path.close()

            // RECENCY STROKE (thin outer outline for recent quick updates)
            if let strokeColor = recencyStroke.color {
                c.saveGState()
                let strokeWidth: CGFloat = 1.5 * zoomMultiplier
                c.setStrokeColor(strokeColor.cgColor)
                c.setLineWidth(strokeWidth * 2)  // Draw wider, then fill covers inner half
                c.addPath(path.cgPath)
                c.strokePath()
                c.restoreGState()
            }

            // HALO (draw outside the shape)
            let halo = (interfaceStyle == .dark)
                ? UIColor.black.withAlphaComponent(0.65)
                : UIColor.white.withAlphaComponent(0.80)
            c.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: halo.cgColor)

            // Fill pin
            c.setFillColor(colorForStatus(status).cgColor)
            c.addPath(path.cgPath)
            c.drawPath(using: .fill)
            c.setShadow(offset: .zero, blur: 0, color: nil) // stop shadow for next steps

            // PUNCH OUT HOLE (true transparency using clear blend mode)
            c.setBlendMode(.clear)
            let holeRect = CGRect(x: bulbCenter.x - holeR, y: bulbCenter.y - holeR,
                                 width: holeR * 2, height: holeR * 2)
            c.fillEllipse(in: holeRect)
            c.setBlendMode(.normal)

            c.restoreGState()
        }
    }
    
    
    private func colorForStatus(_ status: ReportStatus) -> UIColor {
        switch status {
        case .quiet:
            return MarkerPalette.quiet
        case .moderate:
            return MarkerPalette.amber
        case .noisy:
            return MarkerPalette.noisy
        }
    }
}