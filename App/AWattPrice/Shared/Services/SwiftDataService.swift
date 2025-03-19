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
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                url: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: internalAppGroupIdentifier)?
                    .appendingPathComponent("AWattPrice.store"),
                cloudKitDatabase: .none
            )
            
            // Initialize container with shared storage
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("SwiftData model container initialized with shared app group")
            
            // Ensure we have default settings in the database
            ensureSettingsExist(in: modelContainer.mainContext)
            
        } catch {
            fatalError("Failed to create SwiftData model container: \(error.localizedDescription)")
        }
    }
    
    /// Notify the widget that data has changed
    func notifyWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: pricesWidgetKind)
    }
    
    // Make sure we have one instance of each setting
    private func ensureSettingsExist(in context: ModelContext) {
        do {
            // Check for Setting
            let settingDescriptor = FetchDescriptor<Setting>()
            let settings = try context.fetch(settingDescriptor)
            
            if settings.isEmpty {
                // Simply create a new Setting - defaults are already defined in the model
                context.insert(Setting())
                print("Created default Setting")
            }
            
            // Check for NotificationSetting
            let notifDescriptor = FetchDescriptor<NotificationSetting>()
            let notifSettings = try context.fetch(notifDescriptor)
            
            if notifSettings.isEmpty {
                // Simply create a new NotificationSetting - defaults are already defined in the model
                context.insert(NotificationSetting())
                print("Created default NotificationSetting")
            }
            
            try context.save()
            
        } catch {
            print("Error ensuring settings exist: \(error)")
        }
    }
    
    // This method is no longer needed as SettingsManager now handles initialization
    func initializeSettings() {
        // Empty implementation to avoid breaking existing code
        // SettingsManager handles all settings initialization in its constructor
    }
}

/// Settings manager that provides access to app settings
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
        
        // Load settings from SwiftData
        loadSettings()
    }
    
    func loadSettings() {
        // Fetch Setting
        let settingDescriptor = FetchDescriptor<Setting>()
        if let existingSetting = try? context.fetch(settingDescriptor).first {
            self.setting = existingSetting
        } else {
            // Create new setting if none exists
            let newSetting = Setting()
            context.insert(newSetting)
            try? context.save()
            self.setting = newSetting
        }
        
        // Fetch NotificationSetting
        let notifDescriptor = FetchDescriptor<NotificationSetting>()
        if let existingNotifSetting = try? context.fetch(notifDescriptor).first {
            self.notificationSetting = existingNotifSetting
        } else {
            // Create new notification setting if none exists
            let newNotifSetting = NotificationSetting()
            context.insert(newNotifSetting)
            try? context.save()
            self.notificationSetting = newNotifSetting
        }
    }
    
    // Helper method to save changes
    func saveChanges() {
        try? context.save()
        SwiftDataService.shared.notifyWidget()
    }
}
