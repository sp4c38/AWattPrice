//
//  EntityHelpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 06.02.21.
//

import CoreData

func changeSetting<O: NSManagedObject, T: AutoUpdatingSingleEntity<O>>(
    _ setting: T, isNew: (O) -> Bool, bySetting: (O) -> ()
) {
    if setting.entity != nil {
        bySetting(setting.entity!)
        
        do {
            try setting.managedObjectContext.save()
        } catch {
            logger.fault("Couldn't save changes to the managedObjectContext: \(error.localizedDescription).")
        }
    }
}

func saveContext(_ managedObjectContext: NSManagedObjectContext) -> Bool {
    do {
        try managedObjectContext.save()
        return true
    } catch {
        return false
    }
}

fileprivate func handleMoreThenOneEntry<T: NSManagedObject>(
    allItems: [T],
    _ context: NSManagedObjectContext
) -> T {
    logger.fault("Multiple entries found in persistent storage. Only one should exist.")
    let lastElement = allItems.last!
    for entry in allItems.dropLast() {
        context.delete(entry)
    }
    return lastElement
}

fileprivate func getAndInsertNewEntry<T: NSManagedObject>(
    _ entityName: String,
    _ context: NSManagedObjectContext,
    _ setDefaultValues: (T) -> ()
) -> T? {
    let entityDescription = NSEntityDescription.entity(forEntityName: entityName, in: context)
    guard let description = entityDescription else { return nil }
    let newEntry = T(entity: description, insertInto: context)
    setDefaultValues(newEntry)
    return newEntry
}

func getSingleEntry<T: NSManagedObject>(
    _ entityName: String,
    ofAllEntries entries: [T],
    from context: NSManagedObjectContext,
    _ setDefaultValues: (T) -> ()
) -> T? {
    if entries.count <= 0 {
        let newEntry = getAndInsertNewEntry(entityName, context, setDefaultValues) as T?
        guard saveContext(context) == true else { return nil }
        return newEntry
    } else if entries.count == 1 {
        return entries.first!
    } else if entries.count > 1 {
        let entry = handleMoreThenOneEntry(allItems: entries, context) // Removes redundant entries
        guard saveContext(context) == true else { return nil }
        return entry
    }
    return nil
}
