//
//  RegionAndVatSelection.swift
//  AWattPrice
//
//  Created by Léon Becker on 21.11.20.
//

import Resolver
import SwiftUI

extension RegionAndVatSelection {
    class ViewModel: ObservableObject {
        @Injected var currentSetting: CurrentSetting
        @Injected var notificationSetting: CurrentNotificationSetting
        @Injected var notificationService: NotificationService
        
        @Published var selectedRegion: Region = .DE
        @Published var pricesWithTaxIncluded: Bool = false
        
        init() {
            if let region = Region(rawValue: currentSetting.entity!.regionIdentifier) {
                selectedRegion = region
            }
            pricesWithTaxIncluded = currentSetting.entity!.pricesWithVAT
        }
        
        func regionSwitched(to newRegion: Region) {
            if let notificationSettingEntity = self.notificationSetting.entity {
                if notificationService.wantToReceiveAnyNotification(notificationSettingEntity: notificationSettingEntity) {
                    notificationService.ensureAccess { access in
                        if access == true,
                           let tokenContainer = self.notificationService.tokenContainer
                        {
                            let interface = APINotificationInterface(token: tokenContainer.token)
                            let updatedData = UpdatedGeneralData(region: newRegion)
                            let updatePayload = UpdatePayload(subject: .general, updatedData: updatedData)
                            interface.addGeneralUpdateTask(updatePayload)
                            self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting)
                        }
                    }
                } else {
                    self.currentSetting.changeRegionIdentifier(to: newRegion.rawValue)
                }
            }
        }
        
        func taxToggled(to newTaxSelection: Bool) {
            if let notificationSettingEntity = self.notificationSetting.entity {
                if notificationService.wantToReceiveAnyNotification(notificationSettingEntity: notificationSettingEntity) {
                    notificationService.ensureAccess { access in
                        if access == true,
                           let tokenContainer = self.notificationService.tokenContainer
                        {
                            let interface = APINotificationInterface(token: tokenContainer.token)
                            let updatedData = UpdatedGeneralData(tax: newTaxSelection)
                            let updatePayload = UpdatePayload(subject: .general, updatedData: updatedData)
                            interface.addGeneralUpdateTask(updatePayload)
                            self.notificationService.runNotificationRequest(interface: interface, appSetting: self.currentSetting, notificationSetting: self.notificationSetting)
                        }
                    }
                } else {
                    self.currentSetting.changeTaxSelection(to: newTaxSelection)
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
            VStack(alignment: .leading, spacing: 20) {
                Picker(selection: $viewModel.selectedRegion.animation(), label: Text("")) {
                    Text("settingsPage.region.germany")
                        .tag(Region.DE)
                    Text("settingsPage.region.austria")
                        .tag(Region.AT)
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: viewModel.selectedRegion) { newRegion in
                    if newRegion == .AT {
                        viewModel.currentSetting.changeTaxSelection(to: false)
                    }
                    viewModel.regionSwitched(to: newRegion)
                }

                if viewModel.selectedRegion == .DE {
                    HStack(spacing: 10) {
                        Text("settingsPage.priceWithVat")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()

                        Toggle(isOn: $viewModel.pricesWithTaxIncluded) {}
                            .labelsHidden()
                            .onChange(of: viewModel.pricesWithTaxIncluded) { newTaxSelection in
                                viewModel.taxToggled(to: newTaxSelection)
                            }
                    }
                }
            }
        }
    }
}

struct RegionSelection_Previews: PreviewProvider {
    static var previews: some View {
        RegionAndVatSelection()
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
