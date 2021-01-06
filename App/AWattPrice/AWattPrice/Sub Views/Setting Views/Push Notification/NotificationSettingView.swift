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
        .navigationTitle("general.priceGuard")
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
            
            VStack(spacing: 15) {
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
    static var previews: some View {
        GoToNotificationSettingView()
            .preferredColorScheme(.dark)
//        NotificationSettingView()
//            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
//            .environmentObject(CurrentNotificationSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
