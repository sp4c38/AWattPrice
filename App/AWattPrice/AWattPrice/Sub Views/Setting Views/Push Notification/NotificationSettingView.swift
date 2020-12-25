//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI


struct NotificationSettingView: View {
    @State var newPricesNotificationSelection: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            CustomInsetGroupedList {
                NewPricesNotificationView($newPricesNotificationSelection)
            }
        }
        .navigationTitle("notificationPage.notifications")
    }
}

struct GoToNotificationSettingView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var crtNotifiSettings: CurrentNotificationSetting
    
    @State var redirectToNotificationPage: Int? = nil
    
    var body: some View {
        CustomInsetGroupedListItem(
        ) {
            NavigationLink("", destination: NotificationSettingView(), tag: 1, selection: $redirectToNotificationPage)
                .frame(width: 0, height: 0)
                .hidden()
            HStack {
                Image(systemName: "bell")
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
            .onChange(of: redirectToNotificationPage) { newPageSelection in
                if newPageSelection == nil {
                    if let token = crtNotifiSettings.entity!.lastApnsToken {
                        let newConfig = UploadPushNotificationConfigRepresentable(token, crtNotifiSettings.entity!.getNewPricesAvailableNotification)
                        let requestSuccessful = uploadPushNotificationSettings(configuration: newConfig)
                    }
                }
            }
        }
        .customBackgroundColor(colorScheme == .light ? Color(hue: 0.6667, saturation: 0.0202, brightness: 0.9886) : Color(hue: 0.6667, saturation: 0.0340, brightness: 0.1424))
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
