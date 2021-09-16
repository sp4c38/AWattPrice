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

struct NotificationSettingView: View {
    @Environment(\.scenePhase) var scenePhase

    @ObservedObject var notificationService: NotificationService = Resolver.resolve()
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
            CustomInsetGroupedList {
                VStack(spacing: 20) {
                    if notificationService.accessState == .rejected {
                        NoNotificationAccessView()
                            .padding(.top, 10)
                            .transition(.opacity)
                    } else {
                        PriceBelowNotificationView()
                    }
                }
                .animation(.easeInOut)
            }

            VStack {
                if case .failure(_) = notificationService.stateLastUpload {
                    SettingsUploadErrorView()
                        .padding(.bottom, 15)
                }
            }
            .animation(.easeInOut)
        }
        .navigationTitle("general.priceGuard")
    }
}

struct GoToNotificationSettingView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var redirectToNotificationPage: Int? = 0

    var body: some View {
        CustomInsetGroupedListItem(
        ) {
            NavigationLink(
                destination: NotificationSettingView(),
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
    static var notificationService = NotificationService()
    
    static var previews: some View {
        
        return Group {
            GoToNotificationSettingView()

            NotificationSettingView()
                .environmentObject(notificationSettings)
        }
    }
}
