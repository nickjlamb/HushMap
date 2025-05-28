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
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(
            withLatitude: cameraPosition.latitude,
            longitude: cameraPosition.longitude,
            zoom: 12.0
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
        
        // Make sure POIs are visible by default
        mapView.isBuildingsEnabled = true
        
        // Add pins to map
        addPinsToMap(mapView: mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update map type
        mapView.mapType = mapType
        
        // Clear existing markers
        mapView.clear()
        
        // Re-add pins
        addPinsToMap(mapView: mapView)
        
        // Update camera if needed
        let currentPosition = mapView.camera.target
        if abs(currentPosition.latitude - cameraPosition.latitude) > 0.001 ||
           abs(currentPosition.longitude - cameraPosition.longitude) > 0.001 {
            let camera = GMSCameraPosition.camera(
                withLatitude: cameraPosition.latitude,
                longitude: cameraPosition.longitude,
                zoom: mapView.camera.zoom
            )
            mapView.animate(to: camera)
        }
    }
    
    private func addPinsToMap(mapView: GMSMapView) {
        // Add report pins
        for pin in pins {
            let marker = GMSMarker()
            marker.position = pin.coordinate
            marker.title = "Sensory Report"
            marker.snippet = "Quality: \(String(format: "%.1f", pin.qualityRating))"
            
            // Create custom marker icon with quality color
            let markerView = createMarkerView(for: pin)
            marker.iconView = markerView
            marker.userData = pin
            marker.map = mapView
        }
        
        // Add temporary pin if available
        if let tempPin = tempPin {
            let marker = GMSMarker()
            marker.position = tempPin.coordinate
            marker.title = tempPin.name
            marker.snippet = "Tap for prediction"
            
            // Different style for temp pin
            let markerView = createTempMarkerView()
            marker.iconView = markerView
            marker.userData = tempPin
            marker.map = mapView
        }
    }
    
    private func createMarkerView(for pin: ReportPin) -> UIView {
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        markerView.backgroundColor = getQualityColor(for: pin.averageSensoryLevel)
        markerView.layer.cornerRadius = 16
        markerView.layer.borderWidth = 2
        markerView.layer.borderColor = UIColor.white.cgColor
        markerView.layer.shadowColor = UIColor.black.cgColor
        markerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        markerView.layer.shadowOpacity = 0.3
        markerView.layer.shadowRadius = 4
        
        // Add count label if more than one report
        if pin.reportCount > 1 {
            let label = UILabel(frame: markerView.bounds)
            label.text = "\(pin.reportCount)"
            label.textAlignment = .center
            label.font = UIFont.boldSystemFont(ofSize: 12)
            label.textColor = .white
            markerView.addSubview(label)
        }
        
        return markerView
    }
    
    private func createTempMarkerView() -> UIView {
        let markerView = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
        markerView.backgroundColor = UIColor.systemPurple
        markerView.layer.cornerRadius = 16
        markerView.layer.borderWidth = 2
        markerView.layer.borderColor = UIColor.white.cgColor
        markerView.layer.shadowColor = UIColor.black.cgColor
        markerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        markerView.layer.shadowOpacity = 0.3
        markerView.layer.shadowRadius = 4
        
        // Add pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.2
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        markerView.layer.add(pulseAnimation, forKey: "pulse")
        
        return markerView
    }
    
    private func getQualityColor(for rating: Double) -> UIColor {
        switch rating {
        case 0.8...1.0:
            return UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0) // Excellent - Green
        case 0.6..<0.8:
            return UIColor(red: 0.4, green: 0.7, blue: 0.9, alpha: 1.0) // Good - Blue
        case 0.4..<0.6:
            return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0) // Fair - Yellow
        case 0.2..<0.4:
            return UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0) // Poor - Orange
        default:
            return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0) // Very Poor - Red
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
                parent.onPinTap(pin)
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
            // Update the camera position binding if needed
            DispatchQueue.main.async {
                self.parent.cameraPosition = position.target
            }
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
