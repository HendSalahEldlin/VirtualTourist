//
//  PhotoViewController.swift
//  VirtualTourist
//
//  Created by Hend  on 8/15/19.
//  Copyright © 2019 Hend . All rights reserved.
//

import Foundation
import UIKit
import CoreData

class PhotoViewController : UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    // MARK: Properties
    
    // TODO: Add outlet to flowLayout here.
    var pin : Pin!
    var dataController : DataController!
    var fetchedresultController : NSFetchedResultsController<Photo>!
    //var saveObserverToken: Any?
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var Label: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpFetchedResultController()
        if self.pin.pinToPhoto?.count ?? 0 == 0{
            self.configureIndicator(isActive: true)
            self.downloadImages()
        }else{
            self.updateUI(update: true)
        }
        //addSaveNotificationObserver()
    }
    
    deinit {
        //removeSaveNotificationObserver()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedresultController = nil
    }
    
    fileprivate func setUpFetchedResultController() {
        let fetchRequest : NSFetchRequest<Photo> = Photo.fetchRequest()
        let predicator = NSPredicate(format: "photoToPin == %@", pin)
        fetchRequest.predicate = predicator
        let sortDescriptor = NSSortDescriptor(key: "photo", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedresultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedresultController.delegate = self
        do{
            try fetchedresultController.performFetch()
        }catch{
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    // MARK: Collection View Data Source
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedresultController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let photo = fetchedresultController.object(at: indexPath)
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        cell.CellImageView?.image = UIImage(data: (photo.photo!))
        
        return cell
    }
    
    func downloadImages(){
        FlickrClient.sharedInstance().getImagesFromFlickrBySearch(latitude: pin.latitude, longitude: pin.longitude){(resuts, error) in
            
            guard (error == nil) else {
                print("\(error)")
                return
            }
            var count = 0
            let images = resuts! as! [UIImage]
            
            /*let pinId = self.pin.objectID
            let backgroundContext:NSManagedObjectContext = self.dataController.backgroundContext*/
            
            
            for image in images{
                
                let photo = Photo(context: self.dataController.viewContext)
                photo.photo = image.jpegData(compressionQuality: 0.75)
                photo.photoToPin = self.pin
                self.pin.addToPinToPhoto(photo)
                self.hasChanges()
            }
            
            
            DispatchQueue.main.async {                print(self.fetchedresultController.fetchedObjects?.count ?? 0)
                if  self.pin.pinToPhoto?.count ?? 0 == 0{
                    self.updateUI(update: false)
                }else{
                    self.updateUI(update: true)
                }
                self.configureIndicator(isActive: false)
                print("addImages: Photos Count =  \(self.fetchedresultController.fetchedObjects?.count ?? 0)")
            }
        }
    }
    
    // Deletes the `Photo` at the specified index path
    func deletePhoto(at indexPath: IndexPath) {
        let photoToDelete = fetchedresultController.object(at: indexPath)
        dataController.viewContext.delete(photoToDelete)
        hasChanges()
    }
    
    func hasChanges(){
        if self.dataController.viewContext.hasChanges{
            do{
            try? self.dataController.viewContext.save()
            }catch{
                print("hasChanged: \(self.fetchedresultController.fetchedObjects?.count ?? 0)")
            }
        }
    }
    
    func updateUI(update:Bool){
        self.newCollectionButton.isEnabled = update
        self.Label.isHidden = update
        if !update{
            self.Label.text = "No Images"
            self.Label.textAlignment = .center
        }
        //if update{self.collectionView.reloadData()}
    }
    
    func configureIndicator(isActive:Bool){
        if isActive{
            self.activityIndicator.color = UIColor(red: 0.0, green:0.502, blue:0.839, alpha: 1.0)
            self.activityIndicator.startAnimating()
        }else{
            self.activityIndicator.color = UIColor.white
            self.activityIndicator.startAnimating()
        }
    }
   
    @IBAction func ReplaceCollection(_ sender: UIButton) {
        self.configureIndicator(isActive: true)
        let indexPathsToDelete = (collectionView.indexPathsForVisibleItems).sorted().reversed()
        for indexPath in indexPathsToDelete {
            deletePhoto(at: indexPath)
        }
        self.configureIndicator(isActive: true)
        downloadImages()
        self.configureIndicator(isActive: false)
        DispatchQueue.main.async {
            if self.pin.pinToPhoto?.count ?? 0 == 0{
                self.updateUI(update: false)
            }else{
                self.updateUI(update: true)
            }
        }
        
    }
    
    @IBAction func gesture(_ sender: UILongPressGestureRecognizer) {
        if sender.state == UILongPressGestureRecognizer.State.ended{
            let point = sender.location(in: collectionView)
            if let indexPath = collectionView?.indexPathForItem(at: point) {
                let photo = fetchedresultController.object(at: indexPath)
                
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
                cell.backgroundColor = .lightGray
                deletePhoto(at: indexPath)
            }
        }
    }
}


extension PhotoViewController : NSFetchedResultsControllerDelegate{
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            collectionView.insertItems(at: [newIndexPath!])
        case .delete:
            collectionView.deleteItems(at: [indexPath!])
        default:
            break
        }
    }
}

/*extension PhotoViewController {
    func addSaveNotificationObserver(){
        removeSaveNotificationObserver()
        NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: dataController.viewContext, queue: nil, using: handleSaveNotification(notification:))
    }
    
    func removeSaveNotificationObserver(){
        if let token = saveObserverToken{
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    fileprivate func reloadText() {
        collectionView.reloadData()
    }
    
    func handleSaveNotification(notification:Notification){
        DispatchQueue.main.async {
            self.reloadText()
        }
}
}*/
