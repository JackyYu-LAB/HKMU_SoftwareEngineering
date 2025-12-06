import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct AuthView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if let user = authViewModel.user {
                if authViewModel.role == .admin {
                    AdminView()
                } else {
                    ContentView()
                }
            } else {
                LoginView(user: $authViewModel.user, onLogin: {
                    authViewModel.loadUserRole()
                })
            }
        }
        .onAppear {
            authViewModel.setupAuthListener()
        }
    }
}

class AuthViewModel: ObservableObject {
    @Published var user: User? = nil
    @Published var role: UserRole = .customer
    
    private var authListener: AuthStateDidChangeListenerHandle?
    let db = Firestore.firestore()
    
    func setupAuthListener() {
        if authListener == nil {
            authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, authUser in
                self?.user = authUser
                if authUser != nil {
                    self?.loadUserRole()
                }
            }
        }
    }
    
    func loadUserRole() {
        guard let uid = user?.uid else { return }
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error loading user: \(error)")
                return
            }
            if let data = snapshot?.data(), let roleString = data["role"] as? String {
                self?.role = UserRole(rawValue: roleString) ?? .customer
            }
        }
    }
    
    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}

#Preview {
    AuthView()
}
