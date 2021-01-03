//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI
struct NotificationSettingView: View {
    @Environment(\.notificationAccess) var notificationAccess
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            CustomInsetGroupedList {
                VStack(spacing: 20) {
                    VStack {
                        if notificationAccess.access == false {
                            NoNotificationAccessView()
                                .padding(.top, 10)
                                .transition(.opacity)
                        }
                    }
                        
                    PriceDropsBelowValueNotificationView()
                        .opacity(notificationAccess.access == false ? 0.5 : 1)
                        .disabled(notificationAccess.access == false)
                }
                .animation(.easeInOut)
            }
        }
        .navigationTitle("notificationPage.notifications")
    }
}

struct GoToNotificationSettingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var crtNotifiSetting: CurrentNotificationSetting
    @EnvironmentObject var currentSetting: CurrentSetting
    
    @State var redirectToNotificationPage: Int? = nil
    
    var body: some View {
        CustomInsetGroupedListItem(
        ) {
            NavigationLink("", destination: NotificationSettingView(), tag: 1, selection: $redirectToNotificationPage)
                .frame(width: 0, height: 0)
                .hidden()
            HStack {
                Image(systemName: "app.badge")
                    .font(.title2)
                Text("notificationPage.notifications")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Font.caption.weight(.semibold))
                    .foregroundColor(Color.gray)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                redirectToNotificationPage = 1
            }
        }
    }
}

struct NotificationSettingView_Previews: PreviewProvider {
    static var previews: some View {
        GoToNotificationSettingView()
        NotificationSettingView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
