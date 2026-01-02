import UIKit
import GoogleMaps

// MARK: - Marker Configuration
struct MarkerConfig {
    let status: ReportStatus
    let selected: Bool
    let accessibilityLabel: String
    let recentQuickUpdate: RecentQuickUpdateInfo?

    init(status: ReportStatus, selected: Bool, accessibilityLabel: String, recentQuickUpdate: RecentQuickUpdateInfo? = nil) {
        self.status = status
        self.selected = selected
        self.accessibilityLabel = accessibilityLabel
        self.recentQuickUpdate = recentQuickUpdate
    }
}

// MARK: - Marker Provider
final class MarkerProvider {
    static let shared = MarkerProvider()

    private init() {}
    
    func applyIcon(to marker: GMSMarker, config: MarkerConfig, cameraZoom: Float = 15.0, interfaceStyle: UIUserInterfaceStyle = .light) {
        // Clear existing icon to ensure fresh render
        marker.icon = nil
        marker.iconView = nil

        // Force custom markers when there's a recent quick update (needed for recency stroke)
        let hasRecentQuickUpdate = config.recentQuickUpdate?.isRecent ?? false
        let useCustomMarker = MarkerStyleConfig.mode != .googleDefault || hasRecentQuickUpdate

        if !useCustomMarker {
            applyGoogleDefaultMarker(to: marker, status: config.status, selected: config.selected, accessibilityLabel: config.accessibilityLabel, traitEnvironment: UIScreen.main)
        } else {
            applyCustomMarker(to: marker, config: config, cameraZoom: cameraZoom, interfaceStyle: interfaceStyle)
        }
    }
    
    private func applyGoogleDefaultMarker(to marker: GMSMarker, status: ReportStatus, selected: Bool, accessibilityLabel: String, traitEnvironment: UITraitEnvironment) {
        let tint = selected ? status.selectedColor : status.color
        let final = tint.resolvedSRGB(for: traitEnvironment)
        
        // Clear any existing iconView to ensure clean Google marker
        marker.iconView = nil
        
        // Use Google's default marker with our sRGB-resolved color
        marker.icon = GMSMarker.markerImage(with: final)
        marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
        marker.zIndex = selected ? 10 : 1
        marker.tracksViewChanges = false
        
        // Set accessibility on the marker itself
        marker.accessibilityLabel = accessibilityLabel
    }
    
    private func applyCustomMarker(to marker: GMSMarker, config: MarkerConfig, cameraZoom: Float, interfaceStyle: UIUserInterfaceStyle) {
        let size: MarkerSize = config.selected ? .selected : .normal
        let zoomMultiplier = PinSizing.quantizedMultiplier(for: cameraZoom)

        // Determine recency stroke based on quick update state
        let recencyStroke: RecencyStroke
        if let quickUpdate = config.recentQuickUpdate, quickUpdate.isRecent {
            recencyStroke = quickUpdate.quietState == .quiet ? .quiet : .noisy
        } else {
            recencyStroke = .none
        }

        let img = MarkerIconFactory.shared.image(
            for: config.status,
            size: size,
            selected: config.selected,
            scale: UIScreen.main.scale,
            zoomMultiplier: zoomMultiplier,
            interfaceStyle: interfaceStyle,
            recencyStroke: recencyStroke
        )

        // Create improved tap target with 44x44pt hit area
        let tapTargetSize: CGFloat = 44
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: tapTargetSize, height: tapTargetSize))
        containerView.isUserInteractionEnabled = false
        containerView.backgroundColor = UIColor.clear

        let imageView = UIImageView(image: img)
        imageView.contentMode = .center
        imageView.frame = containerView.bounds
        containerView.addSubview(imageView)

        // Use iconView instead of icon for better tap targets
        marker.iconView = containerView

        // Adjust ground anchor for the container - tip should still be at coordinate
        let imageHeight = img.size.height
        let containerHeight = tapTargetSize
        let anchorY = 1.0 - (containerHeight - imageHeight) / (2 * containerHeight)
        marker.groundAnchor = CGPoint(x: 0.5, y: anchorY)

        // Selected markers appear higher with stronger pop
        marker.zIndex = config.selected ? 20 : 5

        // Set up accessibility on the container
        containerView.isAccessibilityElement = true
        containerView.accessibilityLabel = config.accessibilityLabel
    }
    
    // Animate selection with spring effect
    func animateSelection(for marker: GMSMarker) {
        guard let iconView = marker.iconView else { return }
        
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            usingSpringWithDamping: 0.62,
            initialSpringVelocity: 0.0,
            options: [.allowUserInteraction],
            animations: {
                iconView.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            },
            completion: { _ in
                UIView.animate(withDuration: 0.12) {
                    iconView.transform = .identity
                }
            }
        )
    }
    
    // Helper to map comfort score to status
    func statusFromComfort(_ comfort: Double) -> ReportStatus {
        if comfort >= 70 {
            return .quiet
        } else if comfort >= 40 {
            return .moderate
        } else {
            return .noisy
        }
    }
    
    // Helper to refresh markers when zoom bucket changes
    func refreshMarkersForZoom(_ markers: [GMSMarker], cameraZoom: Float, interfaceStyle: UIUserInterfaceStyle) {
        for marker in markers {
            // Extract config from marker's userData if available
            if let pin = marker.userData as? ReportPin {
                let comfortScore = (1.0 - pin.averageSensoryLevel) * 100
                let status = statusFromComfort(comfortScore)
                let config = MarkerConfig(
                    status: status,
                    selected: false, // Reset selection state
                    accessibilityLabel: accessibilityLabel(for: status, location: pin.displayName)
                )
                applyIcon(to: marker, config: config, cameraZoom: cameraZoom, interfaceStyle: interfaceStyle)
            }
        }
    }
    
    // Create accessibility label based on status (simpler for better VoiceOver)
    func accessibilityLabel(for status: ReportStatus, location: String? = nil) -> String {
        let statusText: String
        switch status {
        case .quiet:
            statusText = "Quiet report"
        case .moderate:
            statusText = "Moderate report"
        case .noisy:
            statusText = "Noisy report"
        }
        
        if let location = location {
            return "\(statusText) at \(location)"
        } else {
            return statusText
        }
    }
}