//
//  ViewController.swift
//  GetDirectionsDemo
//
//  Created by Alex Nagy on 12/02/2020.
//  Copyright © 2020 Alex Nagy. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Layoutless
import AVFoundation

class ViewController: UIViewController {
    
    
    var step: [MKRoute.Step] = []
    var stepCount = 0
    var rote: MKRoute?
    var showMapRoute = false
    var navigationStarted = false
    let locationDistance = 500
   
    var speechSynthesizer = AVSpeechSynthesizer()
    
    lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        if CLLocationManager.locationServicesEnabled(){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            handleAuthorizationStatus(locationManager: locationManager, status: CLAuthorizationStatus.authorizedWhenInUse)
        }else{
            print("Location Service is not Enabled")
        }
        return locationManager
    }()
    
    
    
    lazy var directionLabel: UILabel = {
        let label = UILabel()
        label.text = "Where do you want to go?"
        label.font = .boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    lazy var textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your source"
        tf.borderStyle = .roundedRect
        return tf
    }()
    
    lazy var textField1: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your destination"
        tf.borderStyle = .roundedRect
        return tf
    }()
    
    lazy var getDirectionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get Direction", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(getDirectionButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var startStopButton: UIButton = {
        let button = UIButton()
        button.setTitle("Start Navigation", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(startStopButtonTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.delegate = self
        mapView.showsUserLocation = true
        return mapView
    }()
    
    @objc fileprivate func getDirectionButtonTapped() {
       
        guard let destination = textField1.text else {
            return
        }
        showMapRoute = true
        textField1.endEditing(true)
        textField.endEditing(true)
        
        let geoCodder = CLGeocoder()
        geoCodder.geocodeAddressString(destination) { (placemarks, error) in
            if let error = error{
                print(error.localizedDescription)
                return
            }
            guard let placemarks = placemarks,
                let placemark = placemarks.first,
                let location = placemark.location
                else { return }
            let destinationCoordinate = location.coordinate
            self.mapRoute(destinationCoordinate: destinationCoordinate)
        }
        
    }
    
    @objc fileprivate func startStopButtonTapped() {
        
        if !navigationStarted{
            showMapRoute = true
            if let location = locationManager.location{
                let center = location.coordinate
                centerViewToUserLocation(center: center)
            }
        }else{
            if let route = rote{
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: true)
                self.step.removeAll()
                self.stepCount = 0
            }
        }
        
        navigationStarted.toggle()
        startStopButton.setTitle(navigationStarted ? "Stop Navigation":"Start Navigation", for: .normal)
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
       
        setupViews()
        locationManager.startUpdatingLocation()
    }

    fileprivate func setupViews() {
        //view.backgroundColor = .blue
        
        stack(.vertical)(
            directionLabel.insetting(by: 16),
            stack(.vertical, spacing: 16)(
                textField,
                textField1,
                getDirectionButton
            ).insetting(by: 16),
            startStopButton.insetting(by: 16),
            mapView
        ).fillingParent(relativeToSafeArea: true).layout(in: view)
    }
    
    fileprivate func centerViewToUserLocation(center: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: center, latitudinalMeters: CLLocationDistance(locationDistance), longitudinalMeters: CLLocationDistance(locationDistance))
        mapView.setRegion(region, animated: true)
        
    }
    
    fileprivate func handleAuthorizationStatus(locationManager: CLLocationManager, status: CLAuthorizationStatus) {
        switch status {
        
        case .notDetermined:
            //
            locationManager.requestWhenInUseAuthorization()
            break
        case .restricted:
            //
            break
        case .denied:
            //
            break
        case .authorizedAlways:
            //
            break
        case .authorizedWhenInUse:
            if let center = locationManager.location?.coordinate
            {

                centerViewToUserLocation(center: center)
            }
            break
        }
        
    }
   
    fileprivate func mapRoute(destinationCoordinate: CLLocationCoordinate2D) {
        guard let sourceCoordinate = locationManager.location?.coordinate else { return }
        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate)
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        let routeRequest = MKDirections.Request()
        routeRequest.source = sourceItem
        routeRequest.destination = destinationItem
        routeRequest.transportType = .automobile
        
        let direction = MKDirections(request: routeRequest)
        direction.calculate { (responce, error) in
            if let error = error{
                print(error.localizedDescription)
                return
            }
            guard let responce = responce, let routes = responce.routes.first else { return }
            self.rote = routes
            self.mapView.addOverlay(routes.polyline)
            self.mapView.setVisibleMapRect(routes.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), animated: true)
            
            self.getRouteSteps(route: routes)
        }
    }
    
    fileprivate func getRouteSteps(route: MKRoute) {
        
        for monitoredRegion in locationManager.monitoredRegions{
            locationManager.stopMonitoring(for: monitoredRegion)
        }
        guard let steps = rote?.steps else { return }
        self.step = steps
        
        for i in 0..<steps.count {
            let step = 	steps[i]
            print(step.instructions)
            print(step.distance)
            //print(step.transportType)
            //print(step.notice ?? "")

            let region = CLCircularRegion(center: step.polyline.coordinate , radius: 30, identifier: "\(i)")
            locationManager.startMonitoring(for: region)
       }
        stepCount += 1
        let initailMessage = "In \(steps[stepCount].distance) meters \(steps[stepCount].instructions), Then in \(steps[stepCount + 1].distance) meters \(steps[stepCount + 1].instructions) "
        directionLabel.text = initailMessage
        let speechUtterance = AVSpeechUtterance(string: initailMessage)
        speechSynthesizer.speak(speechUtterance)
    }

}

extension ViewController: CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !showMapRoute{
            if let location = locations.last{
                let center = location.coordinate
                centerViewToUserLocation(center: center)
                let ceo: CLGeocoder = CLGeocoder()
                let loc: CLLocation = CLLocation(latitude:center.latitude, longitude: center.longitude)
                ceo.reverseGeocodeLocation(loc, completionHandler:
                    {(placemarks, error) in
                        if (error != nil)
                        {
                            print("reverse geodcode fail: \(error!.localizedDescription)")
                        }
                        let pm = placemarks! as [CLPlacemark]
                        
                        if pm.count > 0 {
                            let pm = placemarks![0]
                            print(pm.country)
                            print(pm.locality)
                            print(pm.subLocality)
                            print(pm.thoroughfare)
                            print(pm.postalCode)
                            print(pm.subThoroughfare)
                            var addressString : String = ""
                            if pm.subLocality != nil {
                                addressString = addressString + pm.subLocality! + ", "
                            }
                            if pm.thoroughfare != nil {
                                addressString = addressString + pm.thoroughfare! + ", "
                            }
                            if pm.locality != nil {
                                addressString = addressString + pm.locality! + ", "
                            }
                            if pm.country != nil {
                                addressString = addressString + pm.country! + ", "
                            }
                            if pm.postalCode != nil {
                                addressString = addressString + pm.postalCode! + " "
                            }
                            
                            self.textField.text = addressString
                            //print(addressString)
                    }
            })
       }
    }
}
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationStatus(locationManager: manager, status: status)
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("didEnterRegion")
        stepCount += 1
        if stepCount < step.count{
           let message = "In \(step[stepCount].distance) meters \(step[stepCount].instructions)"
            directionLabel.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
        }else{
            let message = "You have arrive at your destination"
            directionLabel.text = message
            stepCount = 0
            navigationStarted = false
            for monitoreRegion in locationManager.monitoredRegions{
                locationManager.startMonitoring(for: monitoreRegion)
            }
        }
    }
}
extension ViewController: MKMapViewDelegate{
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = .blue
        return renderer
    }
    
}
