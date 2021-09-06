//
//  RegionAndVatSelection.swift
//  AWattPrice
//
//  Created by Léon Becker on 21.11.20.
//

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
            notificationService.ensureAccess { access in
                if access == true,
                   let tokenContainer = self.notificationService.tokenContainer
                {
                    let interface = APINotificationInterface(token: tokenContainer.token)
                    let updatedData = UpdatedGeneralData(region: newRegion)
                    let updatePayload = UpdatePayload(subject: .general, updatedData: updatedData)
                    interface.addGeneralUpdateTask(updatePayload)
                    self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting, onSuccess: {
                        DispatchQueue.main.async { self.selectedRegion = newRegion }
                    })
                }
            }
        }
        
        func taxToggled(to newTaxSelection: Bool) {
            notificationService.ensureAccess { access in
                if access == true,
                   let tokenContainer = self.notificationService.tokenContainer
                {
                    let interface = APINotificationInterface(token: tokenContainer.token)
                    let updatedData = UpdatedGeneralData(tax: newTaxSelection)
                    let updatePayload = UpdatePayload(subject: .general, updatedData: updatedData)
                    interface.addGeneralUpdateTask(updatePayload)
                    self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting, onSuccess: {
                        DispatchQueue.main.async { self.pricesWithTaxIncluded = newTaxSelection }
                    })
                }
            }
        }
    }
}

struct RegionAndVatSelection: View {
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var viewModel: ViewModel

    @State var firstAppear = true

    init() {
        self.viewModel = ViewModel()
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

struct RegionSelection_Previews: PreviewProvider {
    static var previews: some View {
        RegionAndVatSelection()
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
