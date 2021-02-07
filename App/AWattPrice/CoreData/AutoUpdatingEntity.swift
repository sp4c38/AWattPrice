//
//  CurrentConfigurationSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import CoreData

/* Object which holds a single CoreData entity entry (useful for settings stored in only one setting entry).
 The class informs about changes to the entry by using ObservableObject.
*/
class AutoUpdatingSingleEntity<T: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    var managedObjectContext: NSManagedObjectContext
    let entityController: NSFetchedResultsController<T> // Reports changes in the persistent stored object.
    var entity: T?

    init(
        entityName: String,
        managedObjectContext: NSManagedObjectContext,
        setDefaultValues: (T) -> ()
    ) {
        self.managedObjectContext = managedObjectContext

        let fetchRequest = NSFetchRequest<T>(entityName: entityName)
        fetchRequest.sortDescriptors = []
        entityController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        entityController.delegate = self
        
        entity = getSingleEntry(
            entityName,
            managedObjectContext,
            fetchRequest,
            setDefaultValues
        )
    }

    func controllerWillChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
        objectWillChange.send()
    }
}
