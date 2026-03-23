//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI

extension AnyTransition {
    static var belowScale: AnyTransition {
        .scale.combined(with: .move(edge: .bottom))
    }
}

// Simple enum to replace publisher-based error observer
enum UploadErrorViewState {
    case noError
    case lastUploadFailed
}

@MainActor
class NotificationSettingViewModel: ObservableObject {
    var notificationService: NotificationService
    
    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }
    
    func refreshAccessState() async {
        await notificationService.updateAccessStates()
    }
}

struct NotificationSettingView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var viewModel = NotificationSettingViewModel(notificationService: NotificationService())
    
    var body: some View {
        Form {
            if viewModel.notificationService.accessState == .rejected {
                Section {
                    NoNotificationAccessView()
                        .padding(.top, 10)
                        .transition(.opacity)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    PriceBelowNotificationView()
                }
            }
            
//            if viewModel.uploadErrorState == .lastUploadFailed {
//                Section {
//                    SettingsUploadErrorView()
//                }
//                .listRowBackground(Color.clear)
//            }
        }
        .navigationTitle("Price Guard")
        .task {
            viewModel.notificationService = notificationService
            await viewModel.refreshAccessState()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task { await viewModel.refreshAccessState() }
            }
        }
    }
}

struct NoNotificationAccessView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 30) {
            Text("notificationPage.noNotificationAccessInfo")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)

            Button("Open Settings App") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(RoundedBorderButtonStyle())
        }
    }
}

struct NotificationSettingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NotificationSettingView()
                .environmentObject(NotificationService())
        }
    }
}
