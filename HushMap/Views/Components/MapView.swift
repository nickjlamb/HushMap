import SwiftUI
import GoogleMaps
import CoreLocation
import SwiftData

struct MapView: UIViewRepresentable {
    let mapStyle: GMSMapViewType
    let onMapStyleChanged: (GMSMapViewType) -> Void
    let selectedFilters: FilterOptions
    let startDate: Date
    let endDate: Date
    let pins: [ReportPin]
    
    // External camera position control
    let targetCameraPosition: CLLocationCoordinate2D?
    let shouldUpdateCamera: Bool
    let onCameraUpdated: (() -> Void)?
    
    // Pin tap callback
    let onPinTapped: ((ReportPin) -> Void)?

    // POI tap callback (placeID, name, coordinate)
    let onPOITap: ((String, String, CLLocationCoordinate2D) -> Void)?
    
    @State private var cameraPosition: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @State private var tempPin: PlaceDetails?
    
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
        mapView.mapType = mapStyle
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        
        // Adjust padding to avoid bottom sheet overlap
        // Move location button up by 120pt to clear the bottom sheet peek state
        mapView.padding = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        
        // Enable POI (Points of Interest) display and fix gesture conflicts
        mapView.settings.consumesGesturesInView = true
        
        // Apply performance optimizations
        googleMapsService.optimizeMapView(mapView)

        // Initial markers will be added via updateUIView
        context.coordinator.updateMarkers(
            on: mapView,
            pins: pins,
            tempPin: tempPin,
            deviceCapability: deviceCapability
        )

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update map type
        mapView.mapType = mapStyle

        // Only update markers if pins have actually changed
        if context.coordinator.needsMarkerUpdate(pins: pins, tempPin: tempPin) {
            context.coordinator.updateMarkers(
                on: mapView,
                pins: pins,
                tempPin: tempPin,
                deviceCapability: deviceCapability
            )
        }

        // Handle external camera position updates (e.g., from search)
        if shouldUpdateCamera, let targetPosition = targetCameraPosition {
            let camera = GMSCameraPosition.camera(
                withLatitude: targetPosition.latitude,
                longitude: targetPosition.longitude,
                zoom: 15.0 // Zoom in to the searched location
            )

            // Use device-appropriate animation duration
            CATransaction.begin()
            CATransaction.setAnimationDuration(deviceCapability.getCameraTransitionDuration() * 1.5) // Slightly longer for search navigation
            mapView.animate(to: camera)
            CATransaction.commit()

            // Update internal camera position and notify parent
            DispatchQueue.main.async {
                cameraPosition = targetPosition
                onCameraUpdated?()
            }
        }
        // DISABLE automatic camera updates to prevent snap-back
        // Camera only moves on initial load or explicit search requests
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: MapView
        private var currentPins: [ReportPin] = []
        private var currentTempPin: PlaceDetails?
        private var markers: [GMSMarker] = []

        init(_ parent: MapView) {
            self.parent = parent
        }

        // Check if markers need to be updated
        func needsMarkerUpdate(pins: [ReportPin], tempPin: PlaceDetails?) -> Bool {
            // Check if pin count changed
            if pins.count != currentPins.count {
                return true
            }

            // Check if temp pin changed
            if (tempPin == nil) != (currentTempPin == nil) {
                return true
            }

            if let tp1 = tempPin, let tp2 = currentTempPin {
                if tp1.name != tp2.name ||
                   abs(tp1.coordinate.latitude - tp2.coordinate.latitude) > 0.00001 ||
                   abs(tp1.coordinate.longitude - tp2.coordinate.longitude) > 0.00001 {
                    return true
                }
            }

            // Check if any pin IDs or coordinates changed
            for (index, pin) in pins.enumerated() {
                guard index < currentPins.count else { return true }
                let currentPin = currentPins[index]

                if pin.id != currentPin.id ||
                   abs(pin.coordinate.latitude - currentPin.coordinate.latitude) > 0.00001 ||
                   abs(pin.coordinate.longitude - currentPin.coordinate.longitude) > 0.00001 {
                    return true
                }
            }

            return false
        }

        // Update markers on the map
        func updateMarkers(on mapView: GMSMapView, pins: [ReportPin], tempPin: PlaceDetails?, deviceCapability: DeviceCapabilityService) {
            // Clear existing markers
            markers.forEach { $0.map = nil }
            markers.removeAll()

            // Add new markers using the parent's addPinsToMap logic
            addMarkersToMap(mapView: mapView, pins: pins, tempPin: tempPin)

            // Update tracking
            currentPins = pins
            currentTempPin = tempPin
        }

        private func addMarkersToMap(mapView: GMSMapView, pins: [ReportPin], tempPin: PlaceDetails?) {
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

                // Disable view tracking for performance
                marker.tracksViewChanges = false

                marker.userData = pin
                marker.map = mapView
                markers.append(marker)
            }

            // Add temporary pin if available
            if let tempPin = tempPin {
                let marker = GMSMarker()
                marker.position = tempPin.coordinate
                marker.title = tempPin.name
                marker.snippet = "Tap for prediction"

                if MarkerStyleConfig.mode == .googleDefault {
                    marker.iconView = nil
                    marker.icon = GMSMarker.markerImage(with: .systemPurple)
                    marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
                    marker.tracksViewChanges = false
                    marker.accessibilityLabel = "Predicted location: \(tempPin.name)"
                } else {
                    let interfaceStyle = UITraitCollection.current.userInterfaceStyle
                    let currentZoom = mapView.camera.zoom
                    let zoomMultiplier = PinSizing.quantizedMultiplier(for: currentZoom)
                    let purpleImage = createPurpleTeardropMarker(size: .normal, zoomMultiplier: zoomMultiplier, interfaceStyle: interfaceStyle)

                    let tapTargetSize: CGFloat = 44
                    let containerView = UIView(frame: CGRect(x: 0, y: 0, width: tapTargetSize, height: tapTargetSize))
                    containerView.isUserInteractionEnabled = false
                    containerView.backgroundColor = UIColor.clear

                    let imageView = UIImageView(image: purpleImage)
                    imageView.contentMode = .center
                    imageView.frame = containerView.bounds
                    containerView.addSubview(imageView)

                    marker.iconView = containerView

                    let imageHeight = purpleImage.size.height
                    let containerHeight = tapTargetSize
                    let anchorY = 1.0 - (containerHeight - imageHeight) / (2 * containerHeight)
                    marker.groundAnchor = CGPoint(x: 0.5, y: anchorY)

                    marker.tracksViewChanges = false

                    containerView.isAccessibilityElement = true
                    containerView.accessibilityLabel = "Predicted location: \(tempPin.name)"
                }

                marker.userData = tempPin
                marker.map = mapView
                markers.append(marker)
            }
        }

        // Helper to create purple teardrop for temp pins
        private func createPurpleTeardropMarker(size: MarkerSize, zoomMultiplier: CGFloat = 1.0, interfaceStyle: UIUserInterfaceStyle = .light) -> UIImage {
            let S = size.pointSize * zoomMultiplier

            let padding: CGFloat = 8
            let canvasSize = CGSize(width: S + padding * 2, height: S + padding * 2)

            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

            return renderer.image { ctx in
                let c = ctx.cgContext
                c.saveGState()

                c.translateBy(x: padding, y: padding)

                let tipY = S - 0.5
                let bulbCenter = CGPoint(x: S * 0.5, y: S * 0.44)
                let bulbR = S * 0.34
                let holeR = S * 0.24

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

                let halo = (interfaceStyle == .dark)
                    ? UIColor.black.withAlphaComponent(0.65)
                    : UIColor.white.withAlphaComponent(0.80)
                c.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: halo.cgColor)

                c.setFillColor(UIColor.systemPurple.cgColor)
                c.addPath(path.cgPath)
                c.drawPath(using: .fill)
                c.setShadow(offset: .zero, blur: 0, color: nil)

                c.setBlendMode(.clear)
                let holeRect = CGRect(x: bulbCenter.x - holeR, y: bulbCenter.y - holeR,
                                     width: holeR * 2, height: holeR * 2)
                c.fillEllipse(in: holeRect)
                c.setBlendMode(.normal)

                c.restoreGState()
            }
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
                
                // Handle pin tap - trigger callback to show report details
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Notify parent view about pin tap
                parent.onPinTapped?(pin)
                
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
            } else if marker.userData is PlaceDetails {
                // Handle temporary pin tap - could show prediction
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
            return true
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            // Handle map tap for getting predictions at any location
            // This could trigger adding a temporary prediction pin
            print("Map tapped at: \(coordinate)")
        }
        
        func mapView(_ mapView: GMSMapView, didTapPOIWithPlaceID placeID: String, name: String, location: CLLocationCoordinate2D) {
            // User tapped on a Google Maps POI (business/place)
            print("POI tapped: \(name) with placeID: \(placeID)")

            // Notify parent view about POI tap
            parent.onPOITap?(placeID, name, location)

            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            // Check if zoom bucket changed and refresh markers if needed
            let newZoomBucket = PinSizing.quantizedMultiplier(for: position.zoom)
            if abs(newZoomBucket - parent.lastZoomBucket) > 0.01 {
                parent.lastZoomBucket = newZoomBucket
                refreshMarkersForZoom(mapView: mapView, zoom: position.zoom)
            }
        }

        private func refreshMarkersForZoom(mapView: GMSMapView, zoom: Float) {
            // This is a simplified approach - markers will be refreshed on the next update cycle
            // In a full implementation, you'd track all markers and update them individually
        }
    }
}

// MARK: - Supporting Types

// ReportPin and PlaceDetails are imported from existing definitions in HomeMapView.swift and PlaceService.swift

// Extensions are defined in GoogleMapView.swift