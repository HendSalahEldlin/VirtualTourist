//
//  DataController.swift
//  VirtualTourist
//
//  Created by Hend  on 8/16/19.
//  Copyright © 2019 Hend . All rights reserved.
//

import Foundation
import CoreData

class DataController{
    
    let persistantContainer : NSPersistentContainer
    
    var viewContext:NSManagedObjectContext{
        return persistantContainer.viewContext
    }
    
    //let backgroundContext:NSManagedObjectContext!
    
    /*lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("<dVirualTourist>.sqlite")
        do{
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true]
            coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options)
        }catch{
            fatalError("Error Adding Persistence Store")
        }
        return coordinator
    }()*/
    
    init(modelName:String) {
        persistantContainer = NSPersistentContainer(name: modelName)
        
        /*add necessary support for migration
        let description = NSPersistentStoreDescription()
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        persistantContainer.persistentStoreDescriptions =  [description]*/
        /*add necessary support for migration*/
        //backgroundContext = persistantContainer.newBackgroundContext()
    }
    
    func configureContexts(){
        
        viewContext.automaticallyMergesChangesFromParent = true
        //backgroundContext.automaticallyMergesChangesFromParent = true
        
        //backgroundContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
    
    func load(completion: (() -> Void)? = nil){
        persistantContainer.loadPersistentStores{description, error in
            guard error == nil else{
                fatalError(error!.localizedDescription)
            }
            //self.autoSaveViewContext()
            //self.configureContexts()
            completion?()
        }
    }
}

extension DataController{
    func autoSaveViewContext(interval: TimeInterval = 30){
        print("autoSave")
        if viewContext.hasChanges{
            try? viewContext.save()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            self.autoSaveViewContext()
        }
        
    }
}
