import Combine
import Resolver
import SwiftUI


class RegionTaxSelectionViewModel: ObservableObject {
    var currentSetting: CurrentSetting = Resolver.resolve()
    var notificationSetting: CurrentNotificationSetting = Resolver.resolve()
    var notificationService: NotificationService = Resolver.resolve()
    
    @Published var selectedRegion: Region
    @Published var taxSelection: Bool
    
    let uploadObserver = DownloadPublisherLoadingViewObserver(intervalBeforeExceeded: 0.4)
    
    var cancellables = [AnyCancellable]()
    
    init() {
        selectedRegion = Region(rawValue: currentSetting.entity!.regionIdentifier)!
        taxSelection = currentSetting.entity!.pricesWithVAT
        
        uploadObserver.objectWillChange.receive(on: DispatchQueue.main).sink(receiveValue: { self.objectWillChange.send() }).store(in: &cancellables)
        
        $selectedRegion.dropFirst().sink(receiveValue: regionChanges).store(in: &cancellables)
        $taxSelection.dropFirst().sink(receiveValue: taxSelectionChanges).store(in: &cancellables)
    }
    
    var showTaxSelection: Bool {
        selectedRegion == Region.DE
    }
    
    var isUploading: Bool {
        [.uploadingAndTimeExceeded, .uploadingAndTimeNotExceeded].contains(uploadObserver.loadingPublisher)
    }
    
    var showUploadIndicators: Bool {
        uploadObserver.loadingPublisher == .uploadingAndTimeExceeded
    }
    
    func regionChanges(newRegion: Region) {
        var notificationConfiguration = NotificationConfiguration.create(nil, currentSetting, notificationSetting)
        notificationConfiguration.general.region = newRegion
        let changeSetting = { self.currentSetting.changeRegionIdentifier(to: newRegion.rawValue) }
        
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, forceUploadTrueOnUploadFailure: true) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            downloadPublisher.sink(receiveCompletion: { completion in
                switch completion { case .finished: changeSetting()
                                    case .failure: changeSetting() }
            }, receiveValue: {_ in}).store(in: &self.cancellables)
        } cantStartUpload: {
            self.notificationSetting.changeForceUpload(to: true)
            changeSetting()
        } noUpload: {
            changeSetting()
        }
    }

    func taxSelectionChanges(newTaxSelection: Bool) {
        var notificationConfiguration = NotificationConfiguration.create(nil, currentSetting, notificationSetting)
        notificationConfiguration.general.tax = newTaxSelection
        let changeSetting = { self.currentSetting.changeTaxSelection(to: newTaxSelection) }
        
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, forceUploadTrueOnUploadFailure: true) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            downloadPublisher.sink(receiveCompletion: { completion in
                switch completion { case .finished: changeSetting()
                                    case .failure: changeSetting() }
            }, receiveValue: {_ in}).store(in: &self.cancellables)
        } cantStartUpload: {
            self.notificationSetting.changeForceUpload(to: true)
            changeSetting()
        } noUpload: {
            changeSetting()
        }
    }
}

struct RegionTaxSelectionView: View {
    @StateObject var viewModel = RegionTaxSelectionViewModel()
    
    var changeSelectedRegion: Binding<Region> {
        $viewModel.selectedRegion.setNewValue { newValue in
            withAnimation {
                viewModel.selectedRegion = newValue
            }
        }
    }
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text("settingsPage.region"),
            footer: Text("settingsPage.regionToGetPrices")
        ) {
            ZStack {
                VStack {
                    regionPicker
                    
                    if viewModel.showTaxSelection {
                        taxSelection
                            .padding(.top, 10)
                    }
                }
                .opacity(viewModel.showUploadIndicators ? 0.5 : 1)
                .grayscale(viewModel.showUploadIndicators ? 0.5 : 0)
            
                if viewModel.showUploadIndicators {
                    loadingView
                }
            }
            .disabled(viewModel.isUploading)
        }
    }
    
    var regionPicker: some View {
        Picker("", selection: changeSelectedRegion) {
            Text("settingsPage.region.germany")
                .tag(Region.DE)
            Text("settingsPage.region.austria")
                .tag(Region.AT)
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    var taxSelection: some View {
        Toggle(isOn: $viewModel.taxSelection) {
            Text("settingsPage.priceWithVat")
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
    }
}
