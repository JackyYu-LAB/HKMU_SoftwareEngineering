//
//  FoodOrderingAppApp.swift
//  FoodOrderingApp
//
//  Created by OAO on 2/12/2025.
//

import SwiftUI
import CoreData

@main
struct FoodOrderingAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
