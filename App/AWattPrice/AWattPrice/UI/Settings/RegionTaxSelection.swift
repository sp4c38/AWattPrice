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
    var currentSetting: CurrentSetting
    var notificationSetting: CurrentNotificationSetting
    var notificationService: NotificationService
    
    @Published var selectedRegion: Region
    @Published var taxSelection: Bool
    @Published var isLoading: Bool = false
    
    var cancellables = [AnyCancellable]()
    var showTaxSelection: Bool { selectedRegion == Region.DE }
    
    init(
        currentSetting currentSettingD: CurrentSetting = Resolver.resolve(),
        notificationSetting notificationSettingD: CurrentNotificationSetting = Resolver.resolve(),
        notificationService notificationServiceD: NotificationService = Resolver.resolve()
    ) {
        currentSetting = currentSettingD
        notificationSetting = notificationSettingD
        notificationService = notificationServiceD
        
        selectedRegion = Region(rawValue: currentSetting.entity!.regionIdentifier)!
        taxSelection = currentSetting.entity!.pricesWithVAT
        
        $selectedRegion.dropFirst().sink(receiveValue: regionChanges).store(in: &cancellables)
        $taxSelection.dropFirst().sink(receiveValue: taxSelectionChanges).store(in: &cancellables)
    }
    
    func regionChanges(newRegion: Region) {
        let changeSetting = { self.currentSetting.changeRegionIdentifier(to: newRegion.rawValue) }
        var notificationConfiguration = NotificationConfiguration.create(nil, self.currentSetting, self.notificationSetting)
        notificationConfiguration.general.region = newRegion
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, uploadFinished: changeSetting, uploadError: changeSetting, noUpload: changeSetting)
    }
    
    func taxSelectionChanges(newTaxSelection: Bool) {
        let changeSetting = { self.currentSetting.changeTaxSelection(to: newTaxSelection) }
        var notificationConfiguration = NotificationConfiguration.create(nil, self.currentSetting, self.notificationSetting)
        notificationConfiguration.general.tax = newTaxSelection
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting, uploadFinished: changeSetting, uploadError: changeSetting, noUpload: changeSetting)
    }
}

struct RegionTaxSelectionView: View {
    @ObservedObject var viewModel: RegionTaxSelectionViewModel
    
    init(viewModel: RegionTaxSelectionViewModel = RegionTaxSelectionViewModel()) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        CustomInsetGroupedListItem(
            header: Text("settingsPage.region"),
            footer: Text("settingsPage.regionToGetPrices")
        ) {
            VStack {
                regionPicker
                
                if viewModel.showTaxSelection {
                    taxSelection
                        .padding(.top, 10)
                }
            }
            .opacity(viewModel.isLoading ? 0.6 : 1)
            .disabled(viewModel.isLoading)
        }
        .animation(.easeInOut, value: viewModel.showTaxSelection)
    }
    
    var regionPicker: some View {
        Picker("", selection: $viewModel.selectedRegion) {
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
}

struct RegionTaxSelection_Previews: PreviewProvider {
    static var previews: some View {
        RegionTaxSelectionView()
    }
}
