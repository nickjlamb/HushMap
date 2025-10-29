import SwiftUI
import GoogleMaps
import CoreLocation

struct GoogleMapView: UIViewRepresentable {
    @Binding var mapType: GMSMapViewType
    @Binding var cameraPosition: CLLocationCoordinate2D
    let pins: [ReportPin]
    let onPinTap: (ReportPin) -> Void
    let tempPin: PlaceDetails?
    let onMapTap: ((CLLocationCoordinate2D) -> Void)?
    let onPOITap: ((String, String, CLLocationCoordinate2D) -> Void)?
    
    @ObservedObject private var deviceCapability = DeviceCapabilityService.shared
    private let googleMapsService = GoogleMapsService.shared
    @State private var lastZoomBucket: CGFloat = 1.0
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: cameraPosition.latitude,
            longitude: cameraPosition.longitude,
            zoom: 16.0
        )
        
        let mapView = GMSMapView()
        mapView.camera = camera
        mapView.mapType = mapType
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        
        // Enable POI (Points of Interest) display and fix gesture conflicts
        mapView.settings.consumesGesturesInView = true
        
        // Apply performance optimizations
        googleMapsService.optimizeMapView(mapView)
        
        // Add pins to map with performance consideration
        addPinsToMap(mapView: mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update map type
        mapView.mapType = mapType
        
        // Clear existing markers
        mapView.clear()
        
        // Re-add pins with performance optimization
        addPinsToMap(mapView: mapView)
        
        // Update camera if needed with performance-based animation duration
        let currentPosition = mapView.camera.target
        if abs(currentPosition.latitude - cameraPosition.latitude) > 0.001 ||
           abs(currentPosition.longitude - cameraPosition.longitude) > 0.001 {
            let camera = GMSCameraPosition.camera(
                withLatitude: cameraPosition.latitude,
                longitude: cameraPosition.longitude,
                zoom: mapView.camera.zoom
            )
            
            // Use device-appropriate animation duration
            CATransaction.begin()
            CATransaction.setAnimationDuration(deviceCapability.getCameraTransitionDuration())
            mapView.animate(to: camera)
            CATransaction.commit()
        }
    }
    
    private func addPinsToMap(mapView: GMSMapView) {
        // Add report pins with new teardrop markers
        for pin in pins {
            let marker = GMSMarker()
            marker.position = pin.coordinate
            marker.title = "Sensory Report"
            marker.snippet = "Quality: \(pin.qualityRating)"
            
            // Use new teardrop markers - convert average sensory level (0-1) to comfort (0-100)
            let comfortScore = (1.0 - pin.averageSensoryLevel) * 100
            let status = MarkerProvider.shared.statusFromComfort(comfortScore)
            let config = MarkerConfig(
                status: status,
                selected: false,
                accessibilityLabel: MarkerProvider.shared.accessibilityLabel(
                    for: status,
                    location: pin.displayName
                )
            )
            
            // Get current interface style and zoom
            let interfaceStyle = UITraitCollection.current.userInterfaceStyle
            let currentZoom = mapView.camera.zoom
            MarkerProvider.shared.applyIcon(to: marker, config: config, cameraZoom: currentZoom, interfaceStyle: interfaceStyle)
            
            marker.userData = pin
            marker.map = mapView
        }
        
        // Add temporary pin if available
        if let tempPin = tempPin {
            let marker = GMSMarker()
            marker.position = tempPin.coordinate
            marker.title = tempPin.name
            marker.snippet = "Tap for prediction"
            
            // Use appropriate style for temp pin based on config
            if MarkerStyleConfig.mode == .googleDefault {
                // Use Google's default marker in purple
                marker.iconView = nil
                marker.icon = GMSMarker.markerImage(with: .systemPurple)
                marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
                marker.tracksViewChanges = false
                marker.accessibilityLabel = "Predicted location: \(tempPin.name)"
            } else {
                // Use custom purple teardrop
                let interfaceStyle = UITraitCollection.current.userInterfaceStyle
                let currentZoom = mapView.camera.zoom
                let zoomMultiplier = PinSizing.quantizedMultiplier(for: currentZoom)
                let purpleImage = createPurpleTeardropMarker(size: .normal, zoomMultiplier: zoomMultiplier, interfaceStyle: interfaceStyle)
                
                // Create 44x44 tap target for temp pin too
                let tapTargetSize: CGFloat = 44
                let containerView = UIView(frame: CGRect(x: 0, y: 0, width: tapTargetSize, height: tapTargetSize))
                containerView.isUserInteractionEnabled = false
                containerView.backgroundColor = UIColor.clear
                
                let imageView = UIImageView(image: purpleImage)
                imageView.contentMode = .center
                imageView.frame = containerView.bounds
                containerView.addSubview(imageView)
                
                marker.iconView = containerView
                
                // Adjust ground anchor for temp pin container
                let imageHeight = purpleImage.size.height
                let containerHeight = tapTargetSize
                let anchorY = 1.0 - (containerHeight - imageHeight) / (2 * containerHeight)
                marker.groundAnchor = CGPoint(x: 0.5, y: anchorY)
                
                // Accessibility for temp pin
                containerView.isAccessibilityElement = true
                containerView.accessibilityLabel = "Predicted location: \(tempPin.name)"
            }
            
            marker.userData = tempPin
            marker.map = mapView
        }
    }
    
    // Helper to create purple teardrop for temp pins
    private func createPurpleTeardropMarker(size: MarkerSize, zoomMultiplier: CGFloat = 1.0, interfaceStyle: UIUserInterfaceStyle = .light) -> UIImage {
        let S = size.pointSize * zoomMultiplier
        
        // Canvas with padding for halo
        let padding: CGFloat = 8
        let canvasSize = CGSize(width: S + padding * 2, height: S + padding * 2)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.saveGState()
            
            // Translate to account for padding
            c.translateBy(x: padding, y: padding)
            
            // Geometry (matching main marker)
            let tipY = S - 0.5
            let bulbCenter = CGPoint(x: S * 0.5, y: S * 0.44)
            let bulbR = S * 0.34
            let holeR = S * 0.24
            
            // Outer teardrop path
            let path = UIBezierPath()
            path.addArc(withCenter: bulbCenter, radius: bulbR,
                       startAngle: CGFloat.pi * 1.15, endAngle: CGFloat.pi * -0.15, clockwise: true)
            path.addQuadCurve(to: CGPoint(x: S * 0.50, y: tipY),
                             controlPoint: CGPoint(x: S * 0.86, y: S * 0.86))
            let leftArcEnd = CGPoint(x: bulbCenter.x - bulbR * cos(.pi * 0.15),
                                    y: bulbCenter.y + bulbR * sin(.pi * 0.15))
            path.addQuadCurve(to: leftArcEnd,
                             controlPoint: CGPoint(x: S * 0.14, y: S * 0.86))
            path.close()
            
            // HALO
            let halo = (interfaceStyle == .dark)
                ? UIColor.black.withAlphaComponent(0.65)
                : UIColor.white.withAlphaComponent(0.80)
            c.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: halo.cgColor)
            
            // Fill pin with purple
            c.setFillColor(UIColor.systemPurple.cgColor)
            c.addPath(path.cgPath)
            c.drawPath(using: .fill)
            c.setShadow(offset: .zero, blur: 0, color: nil)
            
            // PUNCH OUT HOLE (true transparency)
            c.setBlendMode(.clear)
            let holeRect = CGRect(x: bulbCenter.x - holeR, y: bulbCenter.y - holeR,
                                 width: holeR * 2, height: holeR * 2)
            c.fillEllipse(in: holeRect)
            c.setBlendMode(.normal)
            
            c.restoreGState()
        }
    }
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let pin = marker.userData as? ReportPin {
                // Update marker to selected state with animation
                let comfortScore = (1.0 - pin.averageSensoryLevel) * 100
                let status = MarkerProvider.shared.statusFromComfort(comfortScore)
                let selectedConfig = MarkerConfig(
                    status: status,
                    selected: true,
                    accessibilityLabel: MarkerProvider.shared.accessibilityLabel(
                        for: status,
                        location: pin.displayName
                    )
                )
                
                // Apply selected state with current zoom and interface style
                let interfaceStyle = UITraitCollection.current.userInterfaceStyle
                let currentZoom = mapView.camera.zoom
                MarkerProvider.shared.applyIcon(to: marker, config: selectedConfig, cameraZoom: currentZoom, interfaceStyle: interfaceStyle)
                MarkerProvider.shared.animateSelection(for: marker)
                
                parent.onPinTap(pin)
                
                // Reset to normal state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let normalConfig = MarkerConfig(
                        status: status,
                        selected: false,
                        accessibilityLabel: MarkerProvider.shared.accessibilityLabel(
                            for: status,
                            location: pin.displayName
                        )
                    )
                    
                    // Reset to normal state with current zoom and interface style
                    let interfaceStyle = UITraitCollection.current.userInterfaceStyle
                    let currentZoom = mapView.camera.zoom
                    MarkerProvider.shared.applyIcon(to: marker, config: normalConfig, cameraZoom: currentZoom, interfaceStyle: interfaceStyle)
                }
            }
            return true
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            // Handle map tap for getting predictions at any location
            parent.onMapTap?(coordinate)
        }
        
        func mapView(_ mapView: GMSMapView, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
            // User tapped on a Google Maps POI (business/place)
            print("POI tapped: \(name) with placeID: \(placeID)")
            parent.onPOITap?(placeID, name, location)
        }
        
        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            // Update the camera position binding
            DispatchQueue.main.async {
                self.parent.cameraPosition = position.target
            }
            
            // Check if zoom bucket changed and refresh markers if needed
            let newZoomBucket = PinSizing.quantizedMultiplier(for: position.zoom)
            if abs(newZoomBucket - parent.lastZoomBucket) > 0.01 {
                parent.lastZoomBucket = newZoomBucket
                
                // Refresh visible markers with new zoom level
                let _ = mapView.selectedMarker != nil ? [mapView.selectedMarker!] : [] // Future: track all visible markers
                // Get all markers from mapView (need to track them)
                refreshMarkersForZoom(mapView: mapView, zoom: position.zoom)
            }
        }
        
        private func refreshMarkersForZoom(mapView: GMSMapView, zoom: Float) {
            // This is a simplified approach - in a real app you'd track all markers
            // For now, we'll let the natural update cycle handle zoom changes
            // The markers will be refreshed on the next updateUIView call
        }
    }
}

extension GMSMapViewType {
    static func from(styleIndex: Int) -> GMSMapViewType {
        switch styleIndex {
        case 0: return .normal
        case 1: return .satellite
        case 2: return .hybrid
        case 3: return .terrain
        default: return .normal
        }
    }
}

// Helper extension for color darkening (if not already defined elsewhere)
extension UIColor {
    func darker(by percentage: CGFloat = 0.2) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: max(0, b * (1 - percentage)), alpha: a)
        }
        return self
    }
}
