//
//  BaseFeeView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.12.22.
//

import Combine
import SwiftUI

class BaseFeeViewModel: ObservableObject {
    var setting: SettingCoreData
    var notificationSetting: NotificationSettingCoreData
    var notificationService: NotificationService
    var energyDataService: EnergyDataService
    
    @Published var baseFee: Double = 0
    
    let uploadErrorObserver = UploadErrorPublisherViewObserver()
    let uploadObserver = DownloadPublisherLoadingViewObserver(intervalBeforeExceeded: 0.4)
    
    var cancellables = [AnyCancellable]()
    
    init(setting: SettingCoreData, notificationSetting: NotificationSettingCoreData, 
         notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.setting = setting
        self.notificationSetting = notificationSetting
        self.notificationService = notificationService
        self.energyDataService = energyDataService
        
        baseFee = setting.entity.baseFee
        
        uploadObserver.objectWillChange.receive(on: DispatchQueue.main).sink(receiveValue: { self.objectWillChange.send() }).store(in: &cancellables)
    }
    
    var isUploading: Bool {
        [.uploadingAndTimeExceeded, .uploadingAndTimeNotExceeded].contains(uploadObserver.loadingPublisher)
    }
    
    var showUploadIndicators: Bool {
        uploadObserver.loadingPublisher == .uploadingAndTimeExceeded
    }
    
    func baseFeeChanges() {
        var notificationConfiguration = NotificationConfiguration.create(nil, setting, notificationSetting)
        notificationConfiguration.general.baseFee = baseFee
        let changeSetting = {
            self.setting.changeSetting { $0.entity.baseFee = self.baseFee }
            DispatchQueue.main.async { self.energyDataService.energyData?.computeValues(with: self.setting) }
        }
        
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            self.uploadErrorObserver.register(for: downloadPublisher.eraseToAnyPublisher())
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


struct BaseFeeView: View {
    @EnvironmentObject var energyDataService: EnergyDataService
    @EnvironmentObject var setting: SettingCoreData
    @EnvironmentObject var notificationSetting: NotificationSettingCoreData
    @EnvironmentObject var notificationService: NotificationService
    
    @StateObject private var viewModel: BaseFeeViewModel
    
    @FocusState var isInputActive: Bool

    init() {
        // Initialize with temporary values that will be replaced in onAppear
        _viewModel = StateObject(wrappedValue: BaseFeeViewModel(
            setting: SettingCoreData(viewContext: CoreDataService.shared.container.viewContext),
            notificationSetting: NotificationSettingCoreData(viewContext: CoreDataService.shared.container.viewContext),
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }

    var body: some View {
        Form {
            Section(header: Text("Info").foregroundColor(.blue)) {
                Text("baseFee.infoText")
            }
            
            if viewModel.notificationSetting.entity.priceDropsBelowValueNotification == true {
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
                                            viewModel.baseFeeChanges()
                                            isInputActive = false
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
            
            
            if viewModel.uploadErrorObserver.viewState == .lastUploadFailed  {
                Section {
                    SettingsUploadErrorView()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Base Fee")
        .onAppear {
            // Update viewModel with the actual environment objects
            viewModel.setting = setting
            viewModel.notificationSetting = notificationSetting
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
            viewModel.baseFee = setting.entity.baseFee
        }
    }
}

struct BaseFeeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BaseFeeView()
                .environmentObject(SettingCoreData(viewContext: CoreDataService.shared.container.viewContext))
                .environmentObject(NotificationSettingCoreData(viewContext: CoreDataService.shared.container.viewContext))
                .environmentObject(NotificationService())
                .environmentObject(EnergyDataService())
        }
    }
}
