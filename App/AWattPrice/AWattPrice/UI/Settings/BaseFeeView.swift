//
//  BaseFeeView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.12.22.
//

import Combine
import SwiftUI

@MainActor
class BaseFeeViewModel: ObservableObject {
    var settingsManager: SettingsManager
    var notificationService: NotificationService
    var energyDataService: EnergyDataService
    
    @Published var baseFee: Double = 0
    @Published var isUploading = false
    @Published var showUploadIndicators = false
    @Published var uploadFailed = false
    
    var cancellables = [AnyCancellable]()
    
    init(settingsManager: SettingsManager, notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        self.energyDataService = energyDataService
        
        baseFee = settingsManager.setting.baseFeePrice
    }
    
    func baseFeeChanges() async {
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.baseFee = baseFee
        
        // Update UI state
        isUploading = true
        showUploadIndicators = true
        
        do {
            // Try to update notification configuration
            _ = try await notificationService.changeNotificationConfiguration(
                notificationConfiguration, 
                settingsManager.setting
            )
            
            // Success case - update local settings
            isUploading = false
            showUploadIndicators = false
            uploadFailed = false
            
            // Update base fee in settings
            settingsManager.setting.baseFeePrice = self.baseFee
            
            // Recompute energy data values with new base fee
            energyDataService.energyData?.computeValues(with: settingsManager.setting)
            
        } catch {
            // Error case - still update local settings but show error
            print("Failed to update notification: \(error)")
            isUploading = false
            showUploadIndicators = false
            uploadFailed = true
        }
    }
}

struct BaseFeeView: View {
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationService: NotificationService
    
    @StateObject private var viewModel: BaseFeeViewModel
    
    @FocusState var isInputActive: Bool

    init() {
        // Initialize with temporary values that will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: BaseFeeViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }

    var body: some View {
        Form {
            Section(header: Text("Info").foregroundColor(.blue)) {
                Text("baseFee.infoText")
            }
            
            if viewModel.settingsManager.setting.priceDropsBelowEnabled == true {
                Section(header: Text("Price Guard").foregroundColor(.green)) {
                    Text("baseFee.priceGuardActivatedInfo")
                }
            }
            
            Section {
                ZStack {
                    VStack(alignment: .leading) {
                        Text("Base fee:")
                            .textCase(.uppercase)
                            .foregroundColor(.gray)
                            .font(.caption)
                        
                        HStack {
                            TextField("", value: $viewModel.baseFee, format: .number)
                                .keyboardType(.decimalPad)
                                .focused($isInputActive)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button(action: {
                                            isInputActive = false
                                            Task { await viewModel.baseFeeChanges() }
                                        }) {
                                            Text("Done")
                                                .bold()
                                        }
                                    }
                                }
                            
                            Text("Cent per kWh")
                        }
                        .modifier(GeneralInputView(markedRed: false))
                    }
                    .opacity(viewModel.showUploadIndicators ? 0.5 : 1)
                    .grayscale(viewModel.showUploadIndicators ? 0.5 : 0)
                    .disabled(viewModel.isUploading)
                    
                    if viewModel.showUploadIndicators {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
            }
            
            if viewModel.uploadFailed {
                Section {
                    SettingsUploadErrorView()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Base Fee")
        .onAppear {
            // Update viewModel with the actual environment objects
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
            viewModel.baseFee = settingsManager.setting.baseFeePrice
        }
    }
}

struct BaseFeeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BaseFeeView()
                .environmentObject(NotificationService())
                .environmentObject(EnergyDataService())
        }
    }
}
