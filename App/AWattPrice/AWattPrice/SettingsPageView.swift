//
//  SettingsPageView.swift
//  AwattarApp
//
//  Created by Léon Becker on 11.09.20.
//

import SceneKit
import SwiftUI

/// A place for the user to modify certain settings. Those changes are automatically stored (if modified) in persistent storage.
struct SettingsPageView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var textFieldCurrentlySelected = false
    
    var body: some View {
        NavigationView {
            CustomInsetGroupedList {
                PricesWithVatIncludedSetting()
                    
                AwattarTariffSelectionSetting(textFieldCurrentlySelected: $textFieldCurrentlySelected)
                
                GetHelpView()
                
                AppVersionView()
            }
            .hideKeyboardWhenBackgroundTapped()
            .navigationTitle("settings")
            .navigationViewStyle(StackNavigationViewStyle())
            .contentShape(Rectangle())
            .navigationBarItems(trailing: DoneNavigationBarItem(presentationMode: presentationMode))
            .ifTrue(textFieldCurrentlySelected) { content in
                content
                    .onTapGesture {
                        self.hideKeyboard()
                    }
            }
        }
    }
    
    struct DoneNavigationBarItem: View {
        @Binding var presentationMode: PresentationMode
        
        var body: some View {
            Button(action: {
                presentationMode.dismiss()
            }) {
                HStack {
                    Text("Done")
                        .bold()
                        .font(.subheadline)
                }
                .foregroundColor(Color.blue)
                .padding(5)
                .padding([.leading, .trailing], 3)
            }
        }
    }
}

struct SettingsPageView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPageView()
            .environment(\.managedObjectContext, PersistenceManager().persistentContainer.viewContext)
            .environmentObject(AwattarData())
            .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
    }
}
