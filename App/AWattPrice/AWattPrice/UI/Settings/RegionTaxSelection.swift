import Combine
import Resolver
import SwiftUI

extension RegionAndVatSelection {
    class ViewModel: ObservableObject {
        @Injected var currentSetting: CurrentSetting
        @Injected var notificationSetting: CurrentNotificationSetting
        @Injected var notificationService: NotificationService

        @Published var areChangeable: Bool = false

        @Published var selectedRegion: Region = .DE
        @Published var pricesWithTaxIncluded: Bool = false

        var cancellables = [AnyCancellable]()

        init() {
            if let region = Region(rawValue: currentSetting.entity!.regionIdentifier) {
                selectedRegion = region
            }
            pricesWithTaxIncluded = currentSetting.entity!.pricesWithVAT

            notificationService.isUploading.$isLocked.sink { newIsUploading in
                DispatchQueue.main.async { self.areChangeable = !newIsUploading }
            }.store(in: &cancellables)
        }

        func regionSwitched(to newRegion: Region) {
            guard let notificationSettingEntity = notificationSetting.entity else { return }

            let changeSelectedRegionInView = {
                DispatchQueue.main.async {
                    self.selectedRegion = newRegion
                }
            }

            notificationService.changeUploadableAttribute(notificationSettingEntity, upload: {
                if let tokenContainer = self.notificationService.tokenContainer {
                    let interface = APINotificationInterface(token: tokenContainer.token)
                    let updatedData = UpdatedGeneralData(region: newRegion)
                    let updatePayload = UpdatePayload(subject: .general, updatedData: updatedData)
                    interface.addGeneralUpdateTask(updatePayload)
                    self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting, onSuccess: {
                        changeSelectedRegionInView()
                    })
                }
            }, noUpload: {
                self.currentSetting.changeRegionIdentifier(to: newRegion.rawValue)
                changeSelectedRegionInView()
            })
        }

        func taxToggled(to newTaxSelection: Bool) {
            guard let notificationSettingEntity = notificationSetting.entity else { return }

            let changeTaxSelectionInView = {
                DispatchQueue.main.async {
                    self.pricesWithTaxIncluded = newTaxSelection
                }
            }

            notificationService.changeUploadableAttribute(notificationSettingEntity, upload: {
                if let tokenContainer = self.notificationService.tokenContainer {
                    let interface = APINotificationInterface(token: tokenContainer.token)
                    let updatedData = UpdatedGeneralData(tax: newTaxSelection)
                    let updatePayload = UpdatePayload(subject: .general, updatedData: updatedData)
                    interface.addGeneralUpdateTask(updatePayload)
                    self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting, onSuccess: {
                        changeTaxSelectionInView()
                    })
                }
            }, noUpload: {
                self.currentSetting.changeTaxSelection(to: newTaxSelection)
                changeTaxSelectionInView()
            })
        }
    }
}

struct RegionAndVatSelection: View {
    @Environment(\.colorScheme) var colorScheme

    @StateObject var viewModel: ViewModel

    @State var firstAppear = true

    init() {
        self._viewModel = StateObject(wrappedValue: ViewModel())
    }

    var body: some View {
        CustomInsetGroupedListItem(
            header: Text("settingsPage.region"),
            footer: Text("settingsPage.regionToGetPrices")
        ) {
            ZStack {
                if !viewModel.areChangeable {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .transition(.opacity)
                }

                VStack(alignment: .leading, spacing: 20) {
                    Picker(selection: $viewModel.selectedRegion.setNewValue { viewModel.regionSwitched(to: $0) }.animation(), label: Text("")) {
                        Text("settingsPage.region.germany")
                            .tag(Region.DE)
                        Text("settingsPage.region.austria")
                            .tag(Region.AT)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if viewModel.selectedRegion == .DE {
                        HStack(spacing: 10) {
                            Text("settingsPage.priceWithVat")
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()

                            Toggle(isOn: $viewModel.pricesWithTaxIncluded.setNewValue { viewModel.taxToggled(to: $0) }) {}
                                .labelsHidden()
                        }
                    }
                }
                .opacity(viewModel.areChangeable ? 1.0 : 0.5)
            }
            .disabled(!viewModel.areChangeable)
        }
        .animation(.easeInOut)
    }
}

class RegionTaxSelectionViewModel: ObservableObject {
    var currentSetting: CurrentSetting = Resolver.resolve()
    
    @Published var selectedRegion: Region
    @Published var pricesWithTax: Bool
    @Published var isLoading: Bool
    
    var cancellables = [AnyCancellable]()
    var showTaxSelection: Bool { selectedRegion == Region.DE }
    
    init() {
        selectedRegion = Region(rawValue: currentSetting.entity!.regionIdentifier)!
        pricesWithTax = currentSetting.entity!.pricesWithVAT
        
        $selectedRegion.sink(receiveValue: regionChanges).store(in: &cancellables)
    }
    
    func regionChanges(newRegion: Region) {
        isLoading = true
        isLoading = false
    }
}

struct RegionTaxSelectionView: View {
    @ObservedObject var viewModel: RegionTaxSelectionViewModel
    
    var body: some View {
        VStack {
            regionPicker
            
            if viewModel.showTaxSelection {
                taxSelection
            }
        }
        .opacity(viewModel.isLoading ? 0.6 : 1)
        .disabled(viewModel.isLoading)
    }
    
    var regionPicker: some View {
        Picker("", selection: $viewModel.selectedRegion) {
            Text("settingsPage.region.germany")
                .tag(Region.DE)
            Text("settingsPage.region.austria")
                .tag(Region.AT)
        }
    }
    
    var taxSelection: some View {
        Toggle(isOn: $viewModel.pricesWithTax) {  }
    }
}

struct RegionTaxSelection_Previews: PreviewProvider {
    static var previews: some View {
        RegionAndVatSelection()
    }
}
