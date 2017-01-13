//
//  AppleMapsOverlayViewController.swift
//
//  IndoorAtlas iOS SDK Swift Examples
//  Apple Maps Overlay Example
//

import UIKit
import MapKit
import IndoorAtlas
import SVProgressHUD

// Class for map overlay object
class MapOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect
    
    var center: CLLocationCoordinate2D
    var rect: MKMapRect
    
    // Initializer for the class
    init(floorPlan: IAFloorPlan) {
        coordinate = floorPlan.center
        boundingMapRect = MKMapRect()
        rect = MKMapRect()
        center = floorPlan.center
        
        //Width and height in MapPoints for the floorplan
        let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(center.latitude)
        let widthMapPoints = floorPlan.widthMeters * Float(mapPointsPerMeter)
        let heightMapPoints = floorPlan.heightMeters * Float(mapPointsPerMeter)
        
        // Area coordinates for the overlay
        let topLeft = MKMapPointForCoordinate(floorPlan.topLeft)
        rect = MKMapRectMake(topLeft.x, topLeft.y, Double(widthMapPoints), Double(heightMapPoints))
        boundingMapRect = rect
    }
}

class MapPin : NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String, subtitle: String) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}

class Ghost : MKCircle {}


// Class for rendering map overlay objects
class MapOverlayRenderer: MKOverlayRenderer {
    var overlayImage: UIImage
    var floorPlan: IAFloorPlan
    
    init(overlay:MKOverlay, overlayImage:UIImage, fp: IAFloorPlan) {
        self.overlayImage = overlayImage
        self.floorPlan = fp
        super.init(overlay: overlay)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        
        let theMapRect = overlay.boundingMapRect
        let theRect = rect(for: theMapRect)
        
        // Rotate around top left corner
        ctx.rotate(by: CGFloat(degreesToRadians(floorPlan.bearing)));
        
        // Draw the floorplan image
        UIGraphicsPushContext(ctx)
        overlayImage.draw(in: theRect, blendMode: CGBlendMode.normal, alpha: 1.0)
        UIGraphicsPopContext();
    }
    
    // Function to convert degrees to radians
    func degreesToRadians(_ x:Double) -> Double {
        return (M_PI * x / 180.0)
    }
}


// View controller for Apple Maps Overlay Example
class AppleMapsOverlayViewController: UIViewController, IALocationManagerDelegate, MKMapViewDelegate {
    
    var floorPlanFetch:AnyObject!
    var imageFetch:AnyObject!
    
    var fpImage = UIImage()
    
    var map = MKMapView()
    var camera = MKMapCamera()
    var updateCamera = Bool()
    var circle = MKCircle()
    var ghost = Ghost()
    var locationList = [IALocation]()
    var lastGhostIndex = 0
    
    // var pin = MapPin(coordinate: CLLocationCoordinate2D(latitude: 0,longitude: 0), title: "Blank", subtitle: "Blank")
    var pin = MKPointAnnotation()
    
    var updatedLocation = CLLocationCoordinate2D(latitude: 0,longitude: 0)
    
    var floorPlan = IAFloorPlan()
    var locationManager = IALocationManager()
    var resourceManager = IAResourceManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pin.coordinate = CLLocationCoordinate2D(latitude: 0,longitude: 0)
        pin.title = "Blank"
        pin.subtitle = "Blank"
        map.addAnnotation(pin)
        
        // Show spinner while waiting for location information from IALocationManager
        SVProgressHUD.show(withStatus:NSLocalizedString("Waiting for location data", comment: ""))
    }
    
    // Hide status bar
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // Function to change the map overlay
    func changeMapOverlay() {
        let overlay = MapOverlay(floorPlan: floorPlan)
        map.add(overlay)
    }
    
    // Function for rendering overlay objects
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        var circleRenderer:MKCircleRenderer!
        
        if overlay is Ghost {
            circleRenderer = MKCircleRenderer(circle: overlay as! MKCircle)
            circleRenderer.fillColor = UIColor(colorLiteralRed: 1, green: 0, blue: 0, alpha: 1.0)
            return circleRenderer
            
        }
            // If it is possible to convert overlay to MKCircle then render the circle with given properties. Else if the overlay is class of MapOverlay set up its own MapOverlayRenderer. Else render red circle.
        else if let overlay = overlay as? MKCircle {
            circleRenderer = MKCircleRenderer(circle: overlay)
            circleRenderer.fillColor = UIColor(colorLiteralRed: 0, green: 0.647, blue: 0.961, alpha: 1.0)
            return circleRenderer
            
        }
        else if overlay is MapOverlay {
            let overlayView = MapOverlayRenderer(overlay: overlay, overlayImage: fpImage, fp: floorPlan)
            return overlayView
            
        }
        else {
            circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.fillColor = UIColor.init(colorLiteralRed: 1, green: 0, blue: 0, alpha: 1.0)
            return circleRenderer
        }
    }
    
    func mapView(_ viewFormapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if (annotation is MKUserLocation) {
            //if annotation is not an MKPointAnnotation (eg. MKUserLocation),
            //return nil so map draws default view for it (eg. blue dot)...
            return nil
        }
        
        let reuseId = "test"
        
        var anView = map.dequeueReusableAnnotationView(withIdentifier: reuseId)
        if anView == nil {
            anView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            //anView.canShowCallout = true
        }
        else {
            //we are re-using a view, update its annotation reference...
            anView?.annotation = annotation
        }
        
        return anView
    }
    
    func indoorLocationManager(_ manager: IALocationManager, didUpdateLocations locations: [AnyObject]) {
        
        // Convert last location to IALocation
        let l = locations.last as! IALocation
        
        // Check that the location is not nil
        if let newLocation = l.location?.coordinate {
            
            SVProgressHUD.dismiss()
            
            // Remove the previous circle overlay and set up a new overlay
            map.remove(circle as MKOverlay)
            circle = MKCircle(center: newLocation, radius: 1)
            map.add(circle)
            
            if (locationList.count > 10) {
                
                // Remove the previous 'ghost' circle overlay and set up a new overlay
                var ghostIndex = locationList.count
                if ((ghostIndex % 3) == 0) {
                    ghostIndex = ghostIndex + 3;
                }
                
                ghostIndex = ghostIndex - 6
                if (lastGhostIndex > ghostIndex) {
                    ghostIndex = lastGhostIndex + 1
                }
                
                let g = locationList[ghostIndex]
                
                if let ghostLocation = g.location?.coordinate {
                    // Remove the previous 'ghost' cirlce overlay and set up a new overlay
                    map.remove(ghost as MKOverlay)
                    ghost = Ghost(center: ghostLocation, radius: 0.5)
                    map.add(ghost)
                }
                
                lastGhostIndex = ghostIndex
            }
            
            locationList.append(l)
            
            // Update annotation
            updatedLocation = newLocation
            pin.coordinate = updatedLocation
            
            var newTitle = "Lat("
            newTitle += String(pin.coordinate.latitude)
            newTitle += "), Long:("
            newTitle += String(pin.coordinate.longitude)
            newTitle += ")"
            
            pin.title = newTitle
            
            // Ask Map Kit for a camera that looks at the location from an altitude of 300 meters above the eye coordinates.
            camera = MKMapCamera(lookingAtCenter: (l.location?.coordinate)!, fromEyeCoordinate: (l.location?.coordinate)!, eyeAltitude: 300)
            
            // Assign the camera to your map view.
            map.camera = camera;
        }
    }
    
    // Fetches image with the given IAFloorplan
    func fetchImage(_ floorPlan:IAFloorPlan) {
        imageFetch = self.resourceManager.fetchFloorPlanImage(with:floorPlan.imageUrl!, andCompletion: { (data, error) in
            if (error != nil) {
                print(error ?? "Default Error Message")
            } else {
                self.fpImage = UIImage.init(data: data!)!
                self.changeMapOverlay()
            }
        })
    }
        
    func indoorLocationManager(_ manager: IALocationManager, didEnter region: IARegion) {
        
        guard region.type == kIARegionTypeFloorPlan else { return }
        
        updateCamera = true
        
        if (floorPlanFetch != nil) {
            // floorPlanFetch.cancel()
            floorPlanFetch = nil
        }
        
        // Fetches the floorplan for the given region identifier
        floorPlanFetch = self.resourceManager.fetchFloorPlan(withId: region.identifier, andCompletion: { (floorplan, error) in
            
            if (error == nil) {
                self.floorPlan = floorplan!
                self.fetchImage(floorplan!)
            } else {
                print("There was an error during floorplan fetch: ", error)
            }
        })
    }
    
    // Authenticate to IndoorAtlas services and request location updates
    func requestLocation() {
        
        let location = IALocation(floorPlanId: kFloorplanId)
        locationManager.location = location
        
        locationManager.delegate = self
        
        resourceManager = IAResourceManager(locationManager: locationManager)!
        
        locationManager.startUpdatingLocation()
    }
    
    // Called when view will appear and sets up the map view and its bounds and delegate. Also requests location
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        updateCamera = true
        
        map = MKMapView()
        map.frame = view.bounds
        map.delegate = self
        view.addSubview(map)
        view.sendSubview(toBack: map)
        
        UIApplication.shared.isStatusBarHidden = true
        
        requestLocation()
    }
    
    // Called when view will disappear and will remove the map from the view and sets its delegate to nil
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        
        map.delegate = nil
        map.removeFromSuperview()
        
        UIApplication.shared.isStatusBarHidden = false
        
        SVProgressHUD.dismiss()
    }
}
