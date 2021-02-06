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
