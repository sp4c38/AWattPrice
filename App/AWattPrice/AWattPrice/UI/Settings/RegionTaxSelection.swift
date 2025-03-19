import SwiftUI

@MainActor
class RegionTaxSelectionViewModel: ObservableObject {
    var settingsManager: SettingsManager
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
    
    init(settingsManager: SettingsManager,notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        self.energyDataService = energyDataService
        
        self.selectedRegion = settingsManager.setting.region
        self.taxSelection = settingsManager.setting.taxEnabled
    }
    
    func regionChanges(newRegion: Region) async {
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.region = newRegion
        
        do {
            // Show loading indicator
            await MainActor.run { isLoading = true }
            
            _ = try await notificationService.changeNotificationConfiguration(notificationConfiguration, settingsManager.setting)
            
            // Update UI elements on main thread
            await MainActor.run {
                self.settingsManager.setting.region = newRegion
                isLoading = false
            }
            
            self.energyDataService.download(region: newRegion, setting: settingsManager.setting)
            
        } catch {
            print("Failed to update notification configuration: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    func taxSelectionChanges(newTaxSelection: Bool) async {
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.tax = newTaxSelection
        
        do {
            // Show loading indicator
            await MainActor.run { isLoading = true }
            
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration,
                settingsManager.setting
            )
            
            await MainActor.run {
                self.settingsManager.setting.taxEnabled = newTaxSelection
                isLoading = false
            }
            
            self.energyDataService.energyData?.computeValues(with: settingsManager.setting)
        } catch {
            print("Failed to update notification configuration: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct RegionTaxSelectionView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var energyDataService: EnergyDataService
    
    @StateObject var viewModel: RegionTaxSelectionViewModel
    
    init() {
        // Initialize with temporary values that will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: RegionTaxSelectionViewModel(
            settingsManager: SettingsManager.shared,
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
            viewModel.settingsManager = settingsManager
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
            .environmentObject(NotificationService())
            .environmentObject(EnergyDataService())
    }
}
