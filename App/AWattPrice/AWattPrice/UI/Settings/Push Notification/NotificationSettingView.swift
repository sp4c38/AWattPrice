//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import Combine
import SwiftUI

extension AnyTransition {
    static var belowScale: AnyTransition {
        let animation = AnyTransition.scale.combined(with: .move(edge: .bottom))
        return AnyTransition.asymmetric(insertion: animation, removal: animation)
    }
}

extension NotificationSettingView {
    class ViewModel {
        let notificationService: NotificationService
        
        init(notificationService: NotificationService) {
            self.notificationService = notificationService
        }
        
        var notificationConfigDisabled: Bool {
            switch notificationService.accessState {
            case .rejected, .notAsked, .unknown:
                return true
            case .granted:
                return false
            }
        }
    }
}

struct NotificationSettingView: View {
    @Environment(\.scenePhase) var scenePhase

    let viewModel: ViewModel
    
    init(notificationService: NotificationService) {
        viewModel = ViewModel(notificationService: notificationService)
    }

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
            CustomInsetGroupedList {
                VStack(spacing: 20) {
                    if viewModel.notificationService.accessState == .rejected {
                        NoNotificationAccessView()
                            .padding(.top, 10)
                            .transition(.opacity)
                    }

                    VStack {
                        PriceDropsBelowValueNotificationView()
                    }
                    .opacity(viewModel.notificationConfigDisabled ? 0.5 : 1)
                    .disabled(viewModel.notificationConfigDisabled)
                }
                .animation(.easeInOut)
            }

            VStack {
                if viewModel.notificationService.apiNotificationUploadState == .uploadFailed {
                    APNSUploadError()
                        .padding(.bottom, 15)
                        .transition(.belowScale)
                }
            }
            .animation(.easeInOut)
        }
        .navigationTitle("general.priceGuard")
    }
}

struct GoToNotificationSettingView: View {
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var notificationService: NotificationService
    
    @State var redirectToNotificationPage: Int? = 0

    var body: some View {
        CustomInsetGroupedListItem(
        ) {
            NavigationLink(
                destination: NotificationSettingView(notificationService: notificationService),
                tag: 1,
                selection: $redirectToNotificationPage
            ) {}
                .frame(width: 0, height: 0)
                .hidden()

            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .center) {
                    Image("PriceTag")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                        .scaledToFit()
                        .frame(width: 22, height: 22, alignment: .center)

                    Text("general.priceGuard")
                        .bold()
                        .font(.body)
                        .padding(.top, 2)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(Font.caption.weight(.semibold))
                        .foregroundColor(Color.gray)
                }

                Text("notificationPage.notification.priceDropsBelowValue.description")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                redirectToNotificationPage = 1
            }
        }
    }
}

struct NotificationSettingView_Previews: PreviewProvider {
    static var appSettings = CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext)
    static var notificationSettings = CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext)
    static var notificationService = NotificationService(appSettings: appSettings, notificationSettings: notificationSettings)
    
    static var previews: some View {
        
        return Group {
            GoToNotificationSettingView()

            NotificationSettingView(notificationService: notificationService)
                .environmentObject(notificationSettings)
        }
    }
}
