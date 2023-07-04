//
//  BaseFeeView.swift
//  AWattPrice
//
//  Created by Léon Becker on 02.12.22.
//

import Combine
import Resolver
import SwiftUI

class BaseFeeViewModel: ObservableObject {
    var setting: SettingCoreData = Resolver.resolve()
    var notificationSetting: NotificationSettingCoreData = Resolver.resolve()
    var notificationService: NotificationService = Resolver.resolve()
    @Injected var energyDataController: EnergyDataController
    
    @Published var baseFee: Double = 0
    
    let uploadErrorObserver = UploadErrorPublisherViewObserver()
    let uploadObserver = DownloadPublisherLoadingViewObserver(intervalBeforeExceeded: 0.4)
    
    var cancellables = [AnyCancellable]()
    
    init() {
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
            DispatchQueue.main.async { self.energyDataController.energyData?.computeValues() }
        }
        
        notificationService.changeNotificationConfiguration(notificationConfiguration, notificationSetting) { downloadPublisher in
            self.uploadObserver.register(for: downloadPublisher.ignoreOutput().eraseToAnyPublisher())
            self.uploadErrorObserver.register(for: downloadPublisher.eraseToAnyPublisher())
            downloadPublisher.sink(receiveCompletion: { completion in
                switch completion {
                case .finished: changeSetting()
                case .failure:
                    self.notificationSetting.changeSetting { $0.entity.forceUpload = true }
                    changeSetting()
                }
            }, receiveValue: {_ in}).store(in: &self.cancellables)
        } cantStartUpload: {
            self.notificationSetting.changeSetting { $0.entity.forceUpload = true }
            changeSetting()
        } noUpload: {
            changeSetting()
        }
    }
}


struct BaseFeeView: View {
    @Injected var energyDataController: EnergyDataController
    @ObservedObject var viewModel = BaseFeeViewModel()
    
    @FocusState var isInputActive: Bool

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
    }
}

struct BaseFeeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BaseFeeView()
        }
    }
}
