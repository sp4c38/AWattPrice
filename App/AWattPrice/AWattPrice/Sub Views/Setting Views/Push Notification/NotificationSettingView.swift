//
//  NotificationSettingView.swift
//  AWattPrice
//
//  Created by Léon Becker on 24.12.20.
//

import SwiftUI


struct NotificationSettingView: View {
    @Environment(\.scenePhase) var scenePhase
    
    @State var priceDropsBelowValueNotificationSelection: Bool = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            CustomInsetGroupedList {
                PriceDropsBelowValueNotificationView($priceDropsBelowValueNotificationSelection)
            }
        }
        .navigationTitle("notificationPage.notifications")
    }
}

func notificationConfigChanged(regionIdentifier: Int, _ crtNotifiSetting: CurrentNotificationSetting) {
    crtNotifiSetting.currentlySendingToServer.lock()
    print("Notification configuration has changed. Trying to upload to server.")
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.main.async {
        crtNotifiSetting.changeChangesButErrorUploading(newValue: false)
        group.leave()
    }
    group.wait()
    
    if let token = crtNotifiSetting.entity!.lastApnsToken {
        let newConfig = UploadPushNotificationConfigRepresentable(token, regionIdentifier: regionIdentifier, crtNotifiSetting.entity!)
        let requestSuccessful = uploadPushNotificationSettings(configuration: newConfig)
        
        if !requestSuccessful {
            DispatchQueue.main.async {
                crtNotifiSetting.changeChangesButErrorUploading(newValue: true)
            }
        }
    } else {
        print("No token is yet set. Will perform upload in background task later.")
        DispatchQueue.main.async {
            crtNotifiSetting.changeChangesButErrorUploading(newValue: true)
        }
    }
    crtNotifiSetting.currentlySendingToServer.unlock()
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
                if newPageSelection == nil && crtNotifiSetting.changesAndStaged == true {
                    DispatchQueue.global(qos: .background).async {
                        notificationConfigChanged(
                            regionIdentifier: Int(currentSetting.entity!.regionIdentifier),
                            crtNotifiSetting)
                        DispatchQueue.main.async {
                            crtNotifiSetting.changesAndStaged = false
                        }
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
