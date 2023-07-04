//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import Combine
import Resolver
import SwiftUI

extension AnyTransition {
    static var belowScale: AnyTransition {
        let animation = AnyTransition.scale.combined(with: .move(edge: .bottom))
        return AnyTransition.asymmetric(insertion: animation, removal: animation)
    }
}

class NotificationSettingViewModel: ObservableObject {
    var notificationService: NotificationService = Resolver.resolve()
    let uploadErrorObserver = UploadErrorPublisherViewObserver()
    
    var cancellables = [AnyCancellable]()
    
    init() {
        notificationService.accessState.receive(on: DispatchQueue.main).sink { _ in self.objectWillChange.send() }.store(in: &cancellables)
        uploadErrorObserver.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send()}).store(in: &cancellables)
    }
}

struct NotificationSettingView: View {
    @Environment(\.scenePhase) var scenePhase

    @StateObject var viewModel = NotificationSettingViewModel()
        
    var body: some View {
        Form {
            if viewModel.notificationService.accessState.value == .rejected {
                Section {
                    NoNotificationAccessView()
                        .padding(.top, 10)
                        .transition(.opacity)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    PriceBelowNotificationView(uploadErrorObserver: viewModel.uploadErrorObserver)
                }
            }
            
            if viewModel.uploadErrorObserver.viewState == .lastUploadFailed {
                Section {
                    SettingsUploadErrorView()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Price Guard")
        .onAppear { print(viewModel.uploadErrorObserver.viewState) }
    }
}

struct NotificationSettingView_Previews: PreviewProvider {
    static var appSettings = SettingCoreData(viewContext: getCoreDataContainer().viewContext)
    static var notificationSettings = NotificationSettingCoreData(viewContext: getCoreDataContainer().viewContext)
    static var notificationService = NotificationService()
    
    static var previews: some View {
        
        return Group {
            NavigationView {
                NotificationSettingView()
                    .environmentObject(notificationSettings)
            }
        }
    }
}
