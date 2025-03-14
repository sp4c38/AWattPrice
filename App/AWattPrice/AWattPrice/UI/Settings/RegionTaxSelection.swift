import Combine
import SwiftUI

class RegionTaxSelectionViewModel: ObservableObject {
    var setting: SettingCoreData
    var notificationSetting: NotificationSettingCoreData
    var notificationService: NotificationService
    var energyDataService: EnergyDataService
    
    @Published var selectedRegion: Region
    @Published var taxSelection: Bool
    
    let uploadObserver = DownloadPublisherLoadingViewObserver(intervalBeforeExceeded: 0.4)
    
    var cancellables = [AnyCancellable]()
    
    init(setting: SettingCoreData, notificationSetting: NotificationSettingCoreData,
         notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.setting = setting
        self.notificationSetting = notificationSetting
        self.notificationService = notificationService
        self.energyDataService = energyDataService
        
        selectedRegion = Region(rawValue: setting.entity.regionIdentifier)!
        taxSelection = setting.entity.pricesWithVAT
        
        uploadObserver.objectWillChange.receive(on: DispatchQueue.main).sink(receiveValue: { self.objectWillChange.send() }).store(in: &cancellables)
        
        $selectedRegion.dropFirst().sink(receiveValue: regionChanges).store(in: &cancellables)
        $taxSelection.dropFirst().sink(receiveValue: taxSelectionChanges).store(in: &cancellables)
    }
    
    var isUploading: Bool {
        [.uploadingAndTimeExceeded, .uploadingAndTimeNotExceeded].contains(uploadObserver.loadingPublisher)
    }
    
    var showUploadIndicators: Bool {
        uploadObserver.loadingPublisher == .uploadingAndTimeExceeded
    }
    
    func regionChanges(newRegion: Region) {
        var notificationConfiguration = NotificationConfiguration.create(nil, setting, notificationSetting)
        notificationConfiguration.general.region = newRegion
        let changeSetting = {
            self.setting.changeSetting { $0.entity.regionIdentifier = newRegion.rawValue }
            DispatchQueue.main.async { self.energyDataService.download(region: newRegion) }
        }
        
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            downloadPublisher.sink(receiveCompletion: { completion in
                changeSetting()
            }, receiveValue: {_ in}).store(in: &self.cancellables)
        } cantStartUpload: {
            changeSetting()
        } noUpload: {
            changeSetting()
        }
    }

    func taxSelectionChanges(newTaxSelection: Bool) {
        var notificationConfiguration = NotificationConfiguration.create(nil, setting, notificationSetting)
        notificationConfiguration.general.tax = newTaxSelection
        let changeSetting = {
            self.setting.changeSetting { $0.entity.pricesWithVAT = newTaxSelection }
            DispatchQueue.main.async { self.energyDataService.energyData?.computeValues(with: self.setting) }
        }

        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            downloadPublisher.sink(receiveCompletion: { completion in
                changeSetting()
            }, receiveValue: {_ in}).store(in: &self.cancellables)
        } cantStartUpload: {
            changeSetting()
        } noUpload: {
            changeSetting()
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
    
    var changeSelectedRegion: Binding<Region> {
        $viewModel.selectedRegion.setNewValue { newValue in
            withAnimation {
                viewModel.selectedRegion = newValue
            }
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                regionPicker
                
                taxSelection
                    .padding(.top, 10)
            }
            .opacity(viewModel.showUploadIndicators ? 0.5 : 1)
            .grayscale(viewModel.showUploadIndicators ? 0.5 : 0)
        
            if viewModel.showUploadIndicators {
                loadingView
            }
        }
        .disabled(viewModel.isUploading)
        .onAppear {
            // Update viewModel with the actual environment objects
            viewModel.setting = setting
            viewModel.notificationSetting = notificationSetting
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
        }
    }
    
    var regionPicker: some View {
        Picker("", selection: changeSelectedRegion) {
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
