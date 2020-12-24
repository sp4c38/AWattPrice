//
//  CurrentSetting.swift
//  AWattPrice
//
//  Created by Léon Becker on 23.12.20.
//

import CoreData

///// Object which holds the current  NotificationSetting object. Using NSFetchedResultsController the current setting stored in this object is updated if any changes occur to it.
//class CurrentNotificationSetting: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
//    // For detailed description see the CurrentSetting file
//    var managedObjectContext: NSManagedObjectContext
//    let settingController: NSFetchedResultsController<Setting>
//    var setting: Setting?
//
//    init(managedObjectContext: NSManagedObjectContext) {
//        self.managedObjectContext = managedObjectContext
//
//        let fetchRequest = NSFetchRequest<Setting>(entityName: "NotificationSetting")
//        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Setting.splashScreensFinished, ascending: true)]
//        settingController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
//
//        super.init()
//        settingController.delegate = self
//        do {
//            try settingController.performFetch()
//        } catch {
//            print("Error performing fetch request on Setting-Item out of Core Data.")
//        }
//
//        setting = getSetting(managedObjectContext: self.managedObjectContext, fetchRequestResults: settingController.fetchedObjects ?? []) ?? nil
//    }
//
//    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        objectWillChange.send()
//    }
//
//    /* Changes the current region which is selected to get aWATTar prices.
//    - Parameter newRegionSelection: The new region which was selected and to which this setting should be changed to.
//    */
//    func changeRegionSelection(newRegionSelection: Int16) {
//        if setting != nil {
//            self.setting!.regionSelection = newRegionSelection
//
//            do {
//                try managedObjectContext.save()
//            } catch {
//                print("managedObjectContext failed to store new regionSelection attribute: \(error).")
//                return
//            }
//        }
//    }
//}
