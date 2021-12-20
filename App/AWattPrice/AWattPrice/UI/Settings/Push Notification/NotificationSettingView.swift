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
        ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
            CustomInsetGroupedList {
                VStack(spacing: 20) {
                    if viewModel.notificationService.accessState.value == .rejected {
                        NoNotificationAccessView()
                            .padding(.top, 10)
                            .transition(.opacity)
                    } else {
                        PriceBelowNotificationView(uploadErrorObserver: viewModel.uploadErrorObserver)
                    }
                }
                .animation(.easeInOut, value: viewModel.notificationService.accessState.value)
            }

            VStack {
                if viewModel.uploadErrorObserver.viewState == .lastUploadFailed {
                    SettingsUploadErrorView()
                        .padding(.bottom, 15)
                        .transition(.belowScale)
                }
            }
            .animation(.easeInOut, value: viewModel.uploadErrorObserver.viewState)
        }
        .navigationTitle("general.priceGuard")
        .onAppear { print(viewModel.uploadErrorObserver.viewState) }
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
