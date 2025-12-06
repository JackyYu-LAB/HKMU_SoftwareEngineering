import SwiftUI
import FirebaseCore

@main
struct FoodOrderingAppApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            AuthView()
        }
    }
}
