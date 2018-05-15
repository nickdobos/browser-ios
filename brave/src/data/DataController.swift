/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import CoreData
import Shared
//import XCGLogger

//      Now that sync is disabled, we hvae fallen back to the original design (from floriankugler)
//      Will update template once issues are ironed out

// After testing many different MOC stacks, it became aparent that main thread context
// should contain no worker children since it will eventually propogate up and block the main
// thread on changes or saves

// Attempting to have the main thread MOC as the sole child of a private MOC seemed optimal 
// (and is recommended path via WWDC Apple CD video), but any associated work on mainMOC
// does not re-merge back into it self well from parent (background) context (tons of issues)
// This should be re-attempted when dropping iOS9, using some of the newer CD APIs for 10+
// (e.g. automaticallyMergesChangesFromParent = true, may allow a complete removal of `merge`)
// StoreCoordinator > writeMOC > mainMOC

// That being said, writeMOC (background) has two parallel children
// One being a mainThreadMOC, and the other a workerMOC. Since contexts seem to have significant
// issues merging their own changes from the parent save, they must merge changes directly from their
// parallel. This seems to work quite well and appears heavily reliable during heavy background work.
// StoreCoordinator > writeMOC (private, no direct work) > mainMOC && workerMOC

// Previoulsy attempted stack which had significant impact on main thread saves
// Follow the stack design from http://floriankugler.com/2013/04/02/the-concurrent-core-data-stack/

class DataController: NSObject {
    static let shared = DataController()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    var mainThreadContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    lazy var workerContext: NSManagedObjectContext = {
        return self.persistentContainer.newBackgroundContext()
    }()
    
    static func remove(object: NSManagedObject, context: NSManagedObjectContext = DataController.shared.persistentContainer.viewContext) {
        context.delete(object)
        DataController.saveContext(context: context)
    }

    static func saveContext(context: NSManagedObjectContext?) {
        guard let context = context else {
            //log.debug("No context on save")
            return
        }
        
        context.perform {
            if !context.hasChanges {
                return
            }

            do {
                try context.save()
                
            } catch {
                fatalError("Error saving DB: \(error)")
            }
        }
    }
}
