//
//  Helpers.swift
//  AWattPrice
//
//  Created by Léon Becker on 06.02.21.
//

import CoreData

func changeSetting<O: NSManagedObject, T: AutoUpdatingEntity<O>>(
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
    if T.self == Setting.self {
        print((newEntry as! Setting).pricesWithVAT)
    }
    return newEntry
}

func getEntry<T: NSManagedObject>(
    _ entityName: String,
    _ context: NSManagedObjectContext,
    _ fetchRequest: NSFetchRequest<T>,
    _ setDefaultValues: (T) -> ()
) -> T? {
    var fetchedEntries: [T]? = nil
    do {
        fetchedEntries = try context.fetch(fetchRequest)
    } catch {
        logger.error("Error performing fetch request on Core Data \"\(entityName)\"-entity: \(error.localizedDescription).")
    }
    guard let entries = fetchedEntries else { return nil }
    
    if entries.count == 1 {
        return entries.first!
    } else if entries.count > 1 {
        let entry = handleMoreThenOneEntry(allItems: entries, context) // Removes redundant entries
        guard saveContext(context) == true else { return nil }
        return entry
    } else if entries.count == 0 {
        let newEntry = getAndInsertNewEntry(entityName, context, setDefaultValues) as T?
        guard saveContext(context) == true else { return nil }
        return newEntry
    }
    return nil
}
