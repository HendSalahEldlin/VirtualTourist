//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Hend  on 8/15/19.
//  Copyright © 2019 Hend . All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CoreData


class MapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    var dataController : DataController!
    var fetchedresultController : NSFetchedResultsController<Pin>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        setUpFetchedResultController()
        self.presentAnnotations()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedresultController = nil
    }
    
    fileprivate func setUpFetchedResultController() {
        let fetchRequest : NSFetchRequest<Pin> = Pin.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "title", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedresultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedresultController.delegate = self
        do{
            try fetchedresultController.performFetch()
        }catch{
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    // Here we create a view with a "right callout accessory view".
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinColor = .red
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    // This delegate method is implemented to respond to taps. It opens the photosView
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        let latPredicate = NSPredicate(format: "latitude = %lf", view.annotation!.coordinate.latitude)
        let longPredicate = NSPredicate(format: "longitude = %lf", view.annotation!.coordinate.longitude)
        let coordinatePredicate = NSCompoundPredicate(type: .and, subpredicates: [latPredicate, longPredicate])
        
        do {
            let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
            let pins = try! dataController.viewContext.fetch(fetchRequest)
            let pinsFound = (pins as NSArray).filtered(using: coordinatePredicate) as! [NSManagedObject]
            if pinsFound.count >= 1 {
                let photoVC = self.storyboard!.instantiateViewController(withIdentifier: "PhotoViewController") as! PhotoViewController
                photoVC.dataController = self.dataController
                photoVC.pin = pinsFound[0] as! Pin
                print("photoVC.pin : \(photoVC.pin.pinToPhoto?.count ?? 0)")
                self.navigationController?.pushViewController(photoVC, animated: true)
                
            }
        }
        
    }
    
    
    @IBAction func addPin(_ sender: UILongPressGestureRecognizer) {
        if (sender.state == UIGestureRecognizer.State.ended){
            let location = sender.location(in: self.mapView)
            let locCoord = self.mapView.convert(location, toCoordinateFrom: self.mapView)
            
            let geoCoder = CLGeocoder()
            let clLoc = CLLocation(latitude: locCoord.latitude, longitude:  locCoord.longitude)
            geoCoder.reverseGeocodeLocation(clLoc, completionHandler: { (placemarks, _) -> Void in
                
                guard let placemark = placemarks?.first else{
                    print("An error occurred while searching for the location.")
                    return
                }
                
                var title = ""
                if let  country = placemark.country{
                    title += country
                }
                if let administrativeArea = placemark.administrativeArea{
                    title += ", " + administrativeArea
                }
                if let locality = placemark.locality{
                    title += ", " + locality
                }
                
                let pin = Pin(context: self.dataController.viewContext)
                pin.latitude = locCoord.latitude
                pin.longitude = locCoord.longitude
                pin.title = title
                self.hasChanges()
                
            })
        }
    }
    
    func hasChanges(){
        if self.dataController.viewContext.hasChanges{
            try? self.dataController.viewContext.save()
        }
    }
    
    func presentAnnotations(){
        if let pins = fetchedresultController.fetchedObjects, pins.count > 0 {
            print(pins.count)
            var annotations = [MKPointAnnotation]()
            for pin in pins {
                let lat = pin.latitude
                let long = pin.longitude
                
                // The lat and long are used to create a CLLocationCoordinates2D instance.
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                
                // Here we create the annotation and set its coordiate, title, and subtitle properties
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = pin.title ?? "Pin"
        
                // Finally we place the annotation in an array of annotations.
                annotations.append(annotation)
            }
            // When the array is complete, we add the annotations to the map.
            self.mapView.addAnnotations(annotations)
        }
    }
    
}

extension MapViewController: NSFetchedResultsControllerDelegate{
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        guard let pin = anObject as? Pin else{
            print("Error")
            return
        }
        
        let point = MKPointAnnotation()
        point.coordinate.latitude = pin.latitude
        point.coordinate.longitude = pin.longitude
        point.title = pin.title
        
        switch type {
        case .insert:
            mapView.addAnnotation(point)
            
        case .delete:
            mapView.removeAnnotation(point)
            
        case .update:
            mapView.removeAnnotation(point)
            mapView.addAnnotation(point)
            
        case .move:
            // N.B. The fetched results controller was set up with a single sort descriptor that produced a consistent ordering for its fetched Point instances.
            fatalError("How did we move a Point? We have a stable sort.")
        }
    }
    
}
