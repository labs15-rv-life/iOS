//
//  AGSMapAPIController.swift
//  RVNav
//
//  Created by Lambda_School_Loaner_214 on 1/21/20.
//  Copyright © 2020 RVNav. All rights reserved.
//

import UIKit
import CoreLocation
import ArcGIS

class AGSMapAPIController: NSObject, MapAPIControllerProtocol, AGSGeoViewTouchDelegate {

    // MARK: - Properties
    var delegate: ViewDelegateProtocol?
    private var destinationAddress: AddressProtocol? {
        didSet{
            let destination = destinationAddress!.location!.coordinate
            end = AGSPoint(clLocationCoordinate2D: destination)
            //let _ = createBarriers()
        }
    }
    internal var avoidanceController: AvoidanceControllerProtocol
    private let graphicsOverlay = AGSGraphicsOverlay()
    private var start: AGSPoint?
    private var end: AGSPoint?
    lazy var mapView: AGSMapView = {
        var newMapView = AGSMapView()
        newMapView.map = AGSMap(basemapType: .navigationVector, latitude: 40.615518, longitude: -74.026005, levelOfDetail: 18)
        newMapView.touchDelegate = self
        newMapView.graphicsOverlays.add(graphicsOverlay)
        return newMapView
    }()
    
    
    private let routeTask = AGSRouteTask(url: URL(string: "https://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World")!)
    
    // MARK: -  Lifecycle
    required init(avoidanceController: AvoidanceControllerProtocol) {
        self.avoidanceController = avoidanceController
        super.init()
        DispatchQueue.main.async {
            self.setupLocationDisplay()
        }
    }
    
    // MARK: - Public Methods
    func search(with address: String, completion: @escaping ([AddressProtocol]?) -> Void) {
        
    }
    
    private func convert(toLongAndLat xPoint: Double, andYPoint yPoint: Double) ->
        CLLocation {
            let originShift: Double = 2 * .pi * 6378137 / 2.0
            let lon: Double = (xPoint / originShift) * 180.0
            var lat: Double = (yPoint / originShift) * 180.0
            lat = 180 / .pi * (2 * atan(exp(lat * .pi / 180.0)) - .pi / 2.0)
            return CLLocation(latitude: lat, longitude: lon)
    }
    
    // Shows alert if there was an error displaying location.
    private func showAlert(withStatus: String) {
        let alertController = UIAlertController(title: "Alert", message:
            withStatus, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        delegate?.present(alertController, animated: true, completion: nil)
        
    }
    
    // Used to display barrier points retrieved from the DS backend.
    private func plotAvoidance() {
        let startCoor = convert(toLongAndLat: mapView.locationDisplay.mapLocation!.x, andYPoint: mapView.locationDisplay.mapLocation!.y)
        
        guard let vehicleInfo = RVSettings.shared.selectedVehicle, let height = vehicleInfo.height, let endLon = destinationAddress?.location?.coordinate.longitude, let endLat = destinationAddress?.location?.coordinate.latitude  else { return }
        
        let routeInfo = RouteInfo(height: height, startLon: startCoor.coordinate.longitude, startLat: startCoor.coordinate.latitude, endLon: endLon, endLat: endLat)
        
        avoidanceController.getAvoidances(with: routeInfo) { (avoidances, error) in
            if let error = error {
                NSLog("error fetching avoidances \(error)")
            }
            if let avoidances = avoidances {
                print(avoidances.count)
                
                DispatchQueue.main.async {
                    for avoid in avoidances {
                        let coor = CLLocationCoordinate2D(latitude: avoid.latitude, longitude: avoid.longitude)
                        let point = AGSPoint(clLocationCoordinate2D: coor)
                        self.addMapMarker(location: point, style: .X, fillColor: .red, outlineColor: .red)
                    }
                }
            }
        }
    }
    
    // Used to call DS backend for getting barriers coordinates.  Each coordinate is turned into a AGSPolygonBarrier and appended to an array.  The array is then returned.
    func createBarriers() -> [AGSPolygonBarrier]{
        let const = 0.0001
        var barriers: [AGSPolygonBarrier] = [] {
            didSet {
                self.findRoute(with: barriers)
            }
        }
        let startCoor = convert(toLongAndLat: mapView.locationDisplay.mapLocation!.x, andYPoint: mapView.locationDisplay.mapLocation!.y)
        
        guard let vehicleInfo = RVSettings.shared.selectedVehicle, let height = vehicleInfo.height, let endLon = destinationAddress?.location?.coordinate.longitude, let endLat = destinationAddress?.location?.coordinate.latitude  else { return []}
        
        let routeInfo = RouteInfo(height: height, startLon: startCoor.coordinate.longitude, startLat: startCoor.coordinate.latitude, endLon: endLon, endLat: endLat)
        
        avoidanceController.getAvoidances(with: routeInfo) { (avoidances, error) in
            if let error = error {
                NSLog("error fetching avoidances \(error)")
            }
            if let avoidances = avoidances {
                var tempBarriers: [AGSPolygonBarrier] = []
                
                for avoid in avoidances {
                    let point = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude + const), longitude: (avoid.longitude + const)))
                    let point1 = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude + const), longitude: (avoid.longitude - const)))
                    let point2 = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude - const), longitude: (avoid.longitude - const)))
                    let point3 = AGSPoint(clLocationCoordinate2D: CLLocationCoordinate2D(latitude: (avoid.latitude - const), longitude: (avoid.longitude + const)))
                    let gon = AGSPolygon(points: [point, point1, point2, point3])
                    let barrier = AGSPolygonBarrier(polygon: gon)
                    
                    tempBarriers.append(barrier)
                    
                    // Used to print out the barriers for testing cxpurposes.
                    
                    //                    let routeSymbol = AGSSimpleLineSymbol(style: .solid, color: .red, width: 8)
                    //                    let routeGraphic = AGSGraphic(geometry: gon, symbol: routeSymbol, attributes: nil)
                    //                    self.graphicsOverlay.graphics.add(routeGraphic)
                }
                barriers = tempBarriers
                print("Barriers count: \(tempBarriers.count)")
            }
        }
        return barriers
    }
    
    // This function sets the default paramaters for finding a route between 2 locations.  Barrier points are used as a parameter.  The route is drawn to the screen.
    func findRoute(with barriers: [AGSPolygonBarrier]) {
        
        routeTask.defaultRouteParameters { [weak self] (defaultParameters, error) in
            guard error == nil else {
                print("Error getting default parameters: \(error!.localizedDescription)")
                return
            }
            
            guard let params = defaultParameters, let self = self, let start = self.mapView.locationDisplay.mapLocation, let end = self.end else { return }
            
            params.setStops([AGSStop(point: start), AGSStop(point: end)])
            params.setPolygonBarriers(barriers)
            
            self.routeTask.solveRoute(with: params, completion: { (result, error) in
                guard error == nil else {
                    print("Error solving route: \(error!.localizedDescription)")
                    return
                }
                #warning("Grok the routes returned")
                if let firstRoute = result?.routes.first, let routePolyline = firstRoute.routeGeometry {
                    let routeSymbol = AGSSimpleLineSymbol(style: .solid, color: .blue, width: 8)
                    let routeGraphic = AGSGraphic(geometry: routePolyline, symbol: routeSymbol, attributes: nil)
                    self.graphicsOverlay.graphics.removeAllObjects()
                    self.graphicsOverlay.graphics.add(routeGraphic)
                    let totalDistance = Measurement(value: firstRoute.totalLength, unit: UnitLength.meters)
                    let totalDuration = Measurement(value: firstRoute.travelTime, unit: UnitDuration.minutes)
                    let formatter = MeasurementFormatter()
                    formatter.numberFormatter.maximumFractionDigits = 2
                    formatter.unitOptions = .naturalScale
                    
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: nil, message: """
                            Total distance: \(formatter.string(from: totalDistance))
                            Travel time: \(formatter.string(from: totalDuration))
                            """, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.delegate?.present(alert, animated: true, completion: nil)
                    }
                }
            })
        }
    }
    
    // adds a mapmarker at a given location.
    private func addMapMarker(location: AGSPoint, style: AGSSimpleMarkerSymbolStyle, fillColor: UIColor, outlineColor: UIColor) {
        let pointSymbol = AGSSimpleMarkerSymbol(style: style, color: fillColor, size: 8)
        pointSymbol.outline = AGSSimpleLineSymbol(style: .solid, color: outlineColor, width: 2)
        let markerGraphic = AGSGraphic(geometry: location, symbol: pointSymbol, attributes: nil)
        graphicsOverlay.graphics.add(markerGraphic)
    }
    
    // Allows users location to be used and displayed on the main mapView.
    private func setupLocationDisplay() {
        mapView.locationDisplay.autoPanMode = .compassNavigation
        mapView.locationDisplay.start { [unowned self] (error:Error?) -> Void in
            if let error = error {
                self.showAlert(withStatus: error.localizedDescription)
            }
        }
    }
}