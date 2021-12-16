import Combine
import Resolver
import SwiftUI

//extension RegionAndVatSelection {
//    class ViewModel: ObservableObject {
//        @Injected var currentSetting: CurrentSetting
//        @Injected var notificationSetting: CurrentNotificationSetting
//        @Injected var notificationService: NotificationService
//
//        @Published var areChangeable: Bool = false
//
//        @Published var selectedRegion: Region = .DE
//        @Published var pricesWithTaxIncluded: Bool = false
//
//        var cancellables = [AnyCancellable]()
//
//        init() {
//            if let region = Region(rawValue: currentSetting.entity!.regionIdentifier) {
//                selectedRegion = region
//            }
//            pricesWithTaxIncluded = currentSetting.entity!.pricesWithVAT
//
//            notificationService.isUploading.$isLocked.sink { newIsUploading in
//                DispatchQueue.main.async { self.areChangeable = !newIsUploading }
//            }.store(in: &cancellables)
//        }
//
//        func regionSwitched(to newRegion: Region) {
//            guard let notificationSettingEntity = notificationSetting.entity else { return }
//
//            let changeSelectedRegionInView = {
//                DispatchQueue.main.async {
//                    self.selectedRegion = newRegion
//                }
//            }
//
//            notificationService.changeUploadableAttribute(notificationSettingEntity, upload: {
//                if let tokenContainer = self.notificationService.tokenContainer {
//                    self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting, onSuccess: {
//                        changeSelectedRegionInView()
//                    })
//                }
//            }, noUpload: {
//                self.currentSetting.changeRegionIdentifier(to: newRegion.rawValue)
//                changeSelectedRegionInView()
//            })
//        }
//
//        func taxToggled(to newTaxSelection: Bool) {
//            guard let notificationSettingEntity = notificationSetting.entity else { return }
//
//            let changeTaxSelectionInView = {
//                DispatchQueue.main.async {
//                    self.pricesWithTaxIncluded = newTaxSelection
//                }
//            }
//
//            notificationService.changeUploadableAttribute(notificationSettingEntity, upload: {
//                if let tokenContainer = self.notificationService.tokenContainer {
//                    let interface = APINotificationInterface(token: tokenContainer.token)
//                    let updatedData = UpdatedGeneralData(tax: newTaxSelection)
//                    let updatePayload = UpdatePayload(subject: .general, updatedData: updatedData)
//                    interface.addGeneralUpdateTask(updatePayload)
//                    self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting, onSuccess: {
//                        changeTaxSelectionInView()
//                    })
//                }
//            }, noUpload: {
//                self.currentSetting.changeTaxSelection(to: newTaxSelection)
//                changeTaxSelectionInView()
//            })
//        }
//    }
//}
//
//struct RegionAndVatSelection: View {
//    @Environment(\.colorScheme) var colorScheme
//
//    @StateObject var viewModel: ViewModel
//
//    @State var firstAppear = true
//
//    init() {
//        self._viewModel = StateObject(wrappedValue: ViewModel())
//    }
//
//    var body: some View {
//        CustomInsetGroupedListItem(
//            header: Text("settingsPage.region"),
//            footer: Text("settingsPage.regionToGetPrices")
//        ) {
//            ZStack {
//                if !viewModel.areChangeable {
//                    ProgressView()
//                        .progressViewStyle(CircularProgressViewStyle())
//                        .transition(.opacity)
//                }
//
//                VStack(alignment: .leading, spacing: 20) {
//                    Picker(selection: $viewModel.selectedRegion.setNewValue { viewModel.regionSwitched(to: $0) }.animation(), label: Text("")) {
//                        Text("settingsPage.region.germany")
//                            .tag(Region.DE)
//                        Text("settingsPage.region.austria")
//                            .tag(Region.AT)
//                    }
//                    .pickerStyle(SegmentedPickerStyle())
//
//                    if viewModel.selectedRegion == .DE {
//                        HStack(spacing: 10) {
//                            Text("settingsPage.priceWithVat")
//                                .font(.subheadline)
//                                .fixedSize(horizontal: false, vertical: true)
//
//                            Spacer()
//
//                            Toggle(isOn: $viewModel.pricesWithTaxIncluded.setNewValue { viewModel.taxToggled(to: $0) }) {}
//                                .labelsHidden()
//                        }
//                    }
//                }
//                .opacity(viewModel.areChangeable ? 1.0 : 0.5)
//            }
//            .disabled(!viewModel.areChangeable)
//        }
//        .animation(.easeInOut)
//    }
//}

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
