import SwiftUI

class RegionTaxSelectionViewModel: ObservableObject {
    var setting: SettingCoreData
    var notificationSetting: NotificationSettingCoreData
    var notificationService: NotificationService
    var energyDataService: EnergyDataService
    
    @Published var selectedRegion: Region {
        didSet {
            if oldValue != selectedRegion {
                Task { await regionChanges(newRegion: selectedRegion) }
            }
        }
    }
    
    @Published var taxSelection: Bool {
        didSet {
            if oldValue != taxSelection {
                Task { await taxSelectionChanges(newTaxSelection: taxSelection) }
            }
        }
    }
    
    @Published private(set) var isLoading = false
    
    init(setting: SettingCoreData, notificationSetting: NotificationSettingCoreData,
         notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.setting = setting
        self.notificationSetting = notificationSetting
        self.notificationService = notificationService
        self.energyDataService = energyDataService
        
        self.selectedRegion = Region(rawValue: setting.entity.regionIdentifier)!
        self.taxSelection = setting.entity.pricesWithVAT
    }
    
    func regionChanges(newRegion: Region) async {
        var notificationConfiguration = NotificationConfiguration.create(nil, setting, notificationSetting)
        notificationConfiguration.general.region = newRegion
        
        do {
            // Show loading indicator
            await MainActor.run { isLoading = true }
            
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration,
                notificationSetting
            )
            
            // Update UI elements on main thread
            await MainActor.run {
                self.setting.changeSetting { $0.entity.regionIdentifier = newRegion.rawValue }
                isLoading = false
            }
            
            self.energyDataService.download(region: newRegion)
            
        } catch {
            print("Failed to update notification configuration: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    func taxSelectionChanges(newTaxSelection: Bool) async {
        var notificationConfiguration = NotificationConfiguration.create(nil, setting, notificationSetting)
        notificationConfiguration.general.tax = newTaxSelection
        
        do {
            // Show loading indicator
            await MainActor.run { isLoading = true }
            
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration,
                notificationSetting
            )
            
            await MainActor.run {
                self.setting.changeSetting { $0.entity.pricesWithVAT = newTaxSelection }
                isLoading = false
            }
            
            self.energyDataService.energyData?.computeValues(with: self.setting)
        } catch {
            print("Failed to update notification configuration: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct RegionTaxSelectionView: View {
    @EnvironmentObject var setting: SettingCoreData
    @EnvironmentObject var notificationSetting: NotificationSettingCoreData
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var energyDataService: EnergyDataService
    
    @StateObject var viewModel: RegionTaxSelectionViewModel
    
    init() {
        // Initialize with temporary values that will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: RegionTaxSelectionViewModel(
            setting: SettingCoreData(viewContext: CoreDataService.shared.container.viewContext),
            notificationSetting: NotificationSettingCoreData(viewContext: CoreDataService.shared.container.viewContext),
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }
    
    var body: some View {
        ZStack {
            VStack {
                regionPicker
                
                taxSelection
                    .padding(.top, 10)
            }
            .opacity(viewModel.isLoading ? 0.5 : 1)
            .grayscale(viewModel.isLoading ? 0.5 : 0)
        
            if viewModel.isLoading {
                loadingView
            }
        }
        .disabled(viewModel.isLoading)
        .onAppear {
            // Update viewModel with the actual environment objects
            viewModel.setting = setting
            viewModel.notificationSetting = notificationSetting
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
        }
    }
    
    var regionPicker: some View {
        Picker("", selection: $viewModel.selectedRegion.animation()) {
            Text("🇩🇪 Germany")
                .tag(Region.DE)
            Text("🇦🇹 Austria")
                .tag(Region.AT)
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    var taxSelection: some View {
        Toggle(isOn: $viewModel.taxSelection) {
            Text("Prices with VAT")
        }
    }
    
    var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
    }
}

struct RegionTaxSelection_Previews: PreviewProvider {
    static var previews: some View {
        RegionTaxSelectionView()
            .environmentObject(SettingCoreData(viewContext: CoreDataService.shared.container.viewContext))
            .environmentObject(NotificationSettingCoreData(viewContext: CoreDataService.shared.container.viewContext))
            .environmentObject(NotificationService())
            .environmentObject(EnergyDataService())
    }
}
