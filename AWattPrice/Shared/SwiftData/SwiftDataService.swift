import Foundation
import SwiftData
import WidgetKit

// Constants used across app and widget
let internalAppGroupIdentifier = "group.me.space8.AWattPrice.internal"
let currentPriceWidgetKind = "me.space8.AWattPrice.currentPrice"
let pricesWidgetKind = "me.space8.AWattPrice.prices"
let cheapestTimesWidgetKind = "me.space8.AWattPrice.cheapestTimes"
let allWidgetKinds = [
    currentPriceWidgetKind,
    pricesWidgetKind,
    cheapestTimesWidgetKind,
]

enum AWattPriceWidgetTimelines {
    static func reloadAll() {
        allWidgetKinds.forEach { kind in
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}

enum ProSupporterEntitlementStore {
    private static let hasProKey = "AWattPrice.hasPro"

    static var hasPro: Bool {
        UserDefaults(suiteName: internalAppGroupIdentifier)?.bool(forKey: hasProKey) ?? false
    }

    static func setHasPro(_ hasPro: Bool) {
        UserDefaults(suiteName: internalAppGroupIdentifier)?.set(hasPro, forKey: hasProKey)
        AWattPriceWidgetTimelines.reloadAll()
    }
}

/// A minimal service that configures SwiftData with app group sharing for widget compatibility
class SwiftDataService {
    static let shared = SwiftDataService()
    
    let modelContainer: ModelContainer
    
    // Create a separate context that can be used outside the main actor
    // This is critical for widget extensions which don't run on the main actor
    private lazy var _backgroundContext: ModelContext = {
        let context = ModelContext(modelContainer)
        return context
    }()
    
    // Public access to a background-safe context
    var backgroundContext: ModelContext {
        _backgroundContext
    }
    
    init() {
        do {
            // Define schema with our model classes
            let schema = Schema([Setting.self])
            
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
            
            // Configure main context on the main actor
            Task { @MainActor in
                self.modelContainer.mainContext.autosaveEnabled = true
            }
        } catch {
            fatalError("Failed to create SwiftData model container: \(error.localizedDescription)")
        }
    }
}

/// Settings manager that provides access to app settings within the main app
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published private(set) var setting: Setting
    
    private let context: ModelContext
    
    private init() {
        // Use mainContext since this is for the main app
        self.context = SwiftDataService.shared.modelContainer.mainContext
        
        // Initialize with defaults in case fetch fails
        self.setting = Setting()
        
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

            do {
                try context.save()
            } catch {
                print("❗ Failed to save context: \(error)")
                // If saving fails, try to recover by recreating the database
                recreateDatabaseIfNeeded(error: error)
            }
            
        } catch {
            print("❕ Error ensuring and loading settings: \(error)")
            recreateDatabaseIfNeeded(error: error)
        }
    }
    
    private func recreateDatabaseIfNeeded(error: Error) {
        // Only attempt this for casting errors which might indicate schema mismatch
        if error.localizedDescription.contains("cast") {
            print("⚠️ Detected potential schema mismatch. Attempting to reset database.")
            // Remove existing items to start fresh
            try? context.delete(model: Setting.self)
            
            // Create a new setting
            let newSetting = Setting()
            context.insert(newSetting)
            self.setting = newSetting
            
            // Try saving again
            try? context.save()
        }
    }
    
    func saveChanges() {
        try? context.save()
        
        AWattPriceWidgetTimelines.reloadAll()
    }
}

/// Simple settings provider that works in extension contexts like widgets
/// Does not use @MainActor to ensure compatibility with background execution
class WidgetSettingsProvider {
    static let shared = WidgetSettingsProvider()
    
    // Not published since widgets don't use Combine
    private(set) var setting: Setting
    
    private let context: ModelContext
    
    private init() {
        // Use the background context that doesn't require MainActor
        self.context = SwiftDataService.shared.backgroundContext
        
        // Initialize with defaults
        self.setting = Setting()
        
        // Load settings (or create defaults)
        loadSettings()
    }

    func reloadSetting() -> Setting {
        loadSettings()
        return setting
    }
    
    private func loadSettings() {
        do {
            let settingDescriptor = FetchDescriptor<Setting>()
            let settings = try context.fetch(settingDescriptor)
            
            if settings.isEmpty {
                // Create a new Setting since none exists
                let newSetting = Setting()
                context.insert(newSetting)
                self.setting = newSetting
                try context.save()
            } else {
                // Use the existing Setting
                self.setting = settings.first!
            }
        } catch {
            print("❕ Error loading settings for widget: \(error)")
            recreateDatabaseIfNeeded()
        }
    }

    private func recreateDatabaseIfNeeded() {
        try? context.delete(model: Setting.self)
        let newSetting = Setting()
        context.insert(newSetting)
        self.setting = newSetting
        try? context.save()
    }
}
