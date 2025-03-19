import Foundation
import SwiftData
import WidgetKit

// Constants used across app and widget
let internalAppGroupIdentifier = "group.me.space8.AWattPrice"
let pricesWidgetKind = "me.space8.AWattPrice.prices"

/// A minimal service that configures SwiftData with app group sharing for widget compatibility
class SwiftDataService {
    static let shared = SwiftDataService()
    
    let modelContainer: ModelContainer
    
    init() {
        do {
            // Define schema with our model classes
            let schema = Schema([Setting.self, NotificationSetting.self])
            
            // Configure container for shared app group storage
            let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: internalAppGroupIdentifier)?
                .appendingPathComponent("AWattPrice.store") ?? URL.documentsDirectory.appendingPathComponent("AWattPrice.store")
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
            
            // Initialize container with shared storage
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("SwiftData model container initialized with shared app group")
            
            // Note: SettingsManager now handles ensuring settings exist
            
        } catch {
            fatalError("Failed to create SwiftData model container: \(error.localizedDescription)")
        }
    }
    
    /// Notify the widget that data has changed
    func notifyWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: pricesWidgetKind)
    }
}

/// Settings manager that provides access to app settings
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published private(set) var setting: Setting
    @Published private(set) var notificationSetting: NotificationSetting
    
    private let context: ModelContext
    
    private init() {
        self.context = SwiftDataService.shared.modelContainer.mainContext
        
        // Initialize with defaults in case fetch fails
        self.setting = Setting()
        self.notificationSetting = NotificationSetting()
        
        // Ensure settings exist and load them in one operation
        ensureAndLoadSettings()
    }
    
    private func ensureAndLoadSettings() {
        do {
            // Check for and load Setting
            let settingDescriptor = FetchDescriptor<Setting>()
            let settings = try context.fetch(settingDescriptor)
            
            if settings.isEmpty {
                // Create a new Setting since none exists
                let newSetting = Setting()
                context.insert(newSetting)
                self.setting = newSetting
                print("Created default Setting")
            } else {
                // Use the existing Setting
                self.setting = settings.first!
            }
            
            // Check for and load NotificationSetting
            let notifDescriptor = FetchDescriptor<NotificationSetting>()
            let notifSettings = try context.fetch(notifDescriptor)
            
            if notifSettings.isEmpty {
                // Create a new NotificationSetting since none exists
                let newNotifSetting = NotificationSetting()
                context.insert(newNotifSetting)
                self.notificationSetting = newNotifSetting
                print("Created default NotificationSetting")
            } else {
                // Use the existing NotificationSetting
                self.notificationSetting = notifSettings.first!
            }
            
            try context.save()
            
        } catch {
            print("Error ensuring and loading settings: \(error)")
        }
    }
    
    // Helper method to save changes
    func saveChanges() {
        try? context.save()
        SwiftDataService.shared.notifyWidget()
    }
}
