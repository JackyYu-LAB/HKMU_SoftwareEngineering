import SwiftUI
import FirebaseFirestore

struct AdminView: View {
    @State private var restaurantName: String = ""
    @State private var cuisine: String = ""
    @State private var rating: Double = 4.5
    @State private var location: String = ""
    @State private var menuItemName: String = ""
    @State private var menuItemPrice: Double = 0.0
    @State private var menuItemDescription: String = ""
    @State private var menuItemAvailable: Bool = true
    @State private var menuItemImageURL: String = ""
    @State private var selectedRestaurant: Restaurant? = nil
    @State private var restaurants: [Restaurant] = []
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmationMessage = ""
    @State private var pendingDeletion: DeletionType? = nil
    @State private var showingEditItemSheet = false
    @State private var currentEditingRestaurant: Restaurant?
    @State private var currentEditingItem: MenuItem?
    @State private var tabSelection = 1
    
    let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            TabView(selection: $tabSelection) {
                addRestaurantView
                    .tabItem { Label("Add Restaurant", systemImage: "plus.circle") }
                    .tag(1)
                
                addMenuItemView
                    .tabItem { Label("Add Menu Item", systemImage: "menucard") }
                    .tag(2)
                
                manageView
                    .tabItem { Label("Manage", systemImage: "trash") }
                    .tag(3)
                
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(4)
            }
            .navigationTitle("Admin Panel")
            .onAppear { loadRestaurants() }
            .alert("Alert", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog(
                "Confirm Delete",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    performPendingDeletion()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(deleteConfirmationMessage)
            }
            .sheet(isPresented: $showingEditItemSheet) {
                if let restaurant = currentEditingRestaurant, let item = currentEditingItem {
                    EditMenuItemView(restaurant: restaurant, item: item) {
                        loadRestaurants()
                    }
                }
            }
        }
    }
    
    private var addRestaurantView: some View {
        Form {
            Section("New Restaurant") {
                TextField("Restaurant Name", text: $restaurantName)
                TextField("Cuisine Type", text: $cuisine)
                TextField("Address (e.g. Tsim Sha Tsui)", text: $location)
                Stepper("Rating: \(rating, specifier: "%.1f")", value: $rating, in: 0...5, step: 0.1)
                Button("Add Restaurant") { addRestaurant() }
                    .disabled(restaurantName.isEmpty || cuisine.isEmpty || location.isEmpty)
            }
        }
        .padding()
    }
    
    private var addMenuItemView: some View {
        Form {
            Section {
                Picker("Select Restaurant", selection: $selectedRestaurant) {
                    Text("Please select").tag(nil as Restaurant?)
                    ForEach(restaurants) { Text($0.name).tag($0 as Restaurant?) }
                }
                TextField("Dish Name", text: $menuItemName)
                TextField("Price", value: $menuItemPrice, format: .number)
                TextField("Description", text: $menuItemDescription)
                Toggle("Available", isOn: $menuItemAvailable)
                TextField("Image URL (optional)", text: $menuItemImageURL)
                Button("Add Dish") { addMenuItem() }
                    .disabled(selectedRestaurant == nil || menuItemName.isEmpty)
            }
        }
        .padding()
    }
    
    private var manageView: some View {
        List {
            if restaurants.isEmpty {
                Text("No restaurants yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(restaurants) { restaurant in
                    Section(header: Text(restaurant.name)) {
                        ForEach(restaurant.menuItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).font(.headline)
                                    if !item.description.isEmpty {
                                        Text(item.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("$\(item.price, specifier: "%.2f")")
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showEditMenuItemSheet(restaurant: restaurant, itemToEdit: item)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    confirmDeleteMenuItem(from: restaurant, item: item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        // 刪除整間餐廳
                        Button {
                            confirmDeleteRestaurant(restaurant: restaurant)
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Restaurant")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .refreshable {  // 添加刷新功能：下拉重新載入餐廳列表
            loadRestaurants()
        }
    }
    
    private func addRestaurant() {
        let newRestaurant = Restaurant(
            id: UUID().uuidString,
            name: restaurantName,
            cuisine: cuisine,
            rating: rating,
            menuItems: [],
            location: location
        )
        
        db.collection("restaurants").addDocument(data: [
            "name": newRestaurant.name,
            "cuisine": newRestaurant.cuisine,
            "rating": newRestaurant.rating,
            "location": newRestaurant.location,
            "menuItems": []
        ]) { err in
            if let err = err { alertMessage = "Add failed: \(err.localizedDescription)"; showAlert = true }
            else {
                loadRestaurants()
                restaurantName = ""; cuisine = ""; location = ""; rating = 4.5
            }
        }
    }
    
    private func addMenuItem() {
        guard let restaurant = selectedRestaurant, !menuItemName.isEmpty else {
            alertMessage = "Please select restaurant and enter dish name"
            showAlert = true
            return
        }
        
        let newItem = MenuItem(
            name: menuItemName,
            price: menuItemPrice,
            description: menuItemDescription,
            isAvailable: menuItemAvailable,
            imageURL: menuItemImageURL.isEmpty ? nil : menuItemImageURL
        )
        
        let dict: [String: Any] = [
            "id": newItem.id,
            "name": newItem.name,
            "price": newItem.price,
            "description": newItem.description,
            "isAvailable": newItem.isAvailable,
            "imageURL": newItem.imageURL as Any
        ]
        
        db.collection("restaurants").document(restaurant.id).updateData([
            "menuItems": FieldValue.arrayUnion([dict])
        ]) { err in
            if let err = err {
                alertMessage = "Add failed: \(err.localizedDescription)"
                showAlert = true
            } else {
                loadRestaurants()
                menuItemName = ""
                menuItemPrice = 0
                menuItemDescription = ""
                menuItemImageURL = ""
                menuItemAvailable = true
                
                tabSelection = 3
            }
        }
    }
    
    private func loadRestaurants() {
        db.collection("restaurants").getDocuments { snapshot, err in
            if let err = err { alertMessage = err.localizedDescription; showAlert = true; return }
            var list: [Restaurant] = []
            for doc in snapshot?.documents ?? [] {
                let data = doc.data()
                let id = doc.documentID
                let name = data["name"] as? String ?? ""
                let cuisine = data["cuisine"] as? String ?? ""
                let rating = data["rating"] as? Double ?? 4.5
                let location = data["location"] as? String ?? ""
                var items: [MenuItem] = []
                if let array = data["menuItems"] as? [[String: Any]] {
                    for d in array {
                        let itemId = d["id"] as? String ?? UUID().uuidString
                        items.append(MenuItem(
                            name: d["name"] as? String ?? "",
                            price: d["price"] as? Double ?? 0,
                            description: d["description"] as? String ?? "",
                            isAvailable: d["isAvailable"] as? Bool ?? true,
                            imageURL: d["imageURL"] as? String
                        ))
                    }
                }
                list.append(Restaurant(id: id, name: name, cuisine: cuisine, rating: rating, menuItems: items, location: location))
            }
            DispatchQueue.main.async {
                self.restaurants = []           // 先清空 → 觸發 SwiftUI 重繪
                self.restaurants = list         // 再賦值 → 正確顯示最新資料
                
                if self.selectedRestaurant == nil && !list.isEmpty {
                    self.selectedRestaurant = list.first
                }
            }
        }
    }
    
    private func showEditMenuItemSheet(restaurant: Restaurant, itemToEdit: MenuItem) {
        currentEditingRestaurant = restaurant
        currentEditingItem = itemToEdit
        showingEditItemSheet = true
    }
}

extension AdminView {
    static func updateMenuItem(
        in restaurant: Restaurant,
        updatedItem: MenuItem,
        onComplete: @escaping () -> Void
    ) {
        let db = Firestore.firestore()
        
        let dict: [String: Any] = [
            "id": updatedItem.id,
            "name": updatedItem.name,
            "price": updatedItem.price,
            "description": updatedItem.description,
            "isAvailable": updatedItem.isAvailable,
            "imageURL": updatedItem.imageURL as Any? ?? NSNull()
        ]
        
        let oldDict: [String: Any] = [
            "id": updatedItem.id,
            "name": updatedItem.name,
            "price": updatedItem.price,
            "description": updatedItem.description,
            "isAvailable": updatedItem.isAvailable,
            "imageURL": updatedItem.imageURL as Any? ?? NSNull()
        ]
        
        db.collection("restaurants").document(restaurant.id).updateData([
            "menuItems": FieldValue.arrayRemove([oldDict])
        ]) { _ in
            db.collection("restaurants").document(restaurant.id).updateData([
                "menuItems": FieldValue.arrayUnion([dict])
            ]) { _ in
                onComplete()
            }
        }
    }
    
    private func confirmDeleteRestaurant(restaurant: Restaurant) {
        deleteConfirmationMessage = "Are you sure you want to delete \(restaurant.name) and all its menu items?"
        pendingDeletion = .restaurant(restaurant)
        showingDeleteConfirmation = true
    }
    
    private func confirmDeleteMenuItem(from restaurant: Restaurant, item: MenuItem) {
        deleteConfirmationMessage = "Are you sure you want to delete \(item.name)?"
        pendingDeletion = .menuItem(restaurant: restaurant, item: item)
        showingDeleteConfirmation = true
    }
    
    private func performPendingDeletion() {
        switch pendingDeletion {
        case .restaurant(let restaurant):
            db.collection("restaurants").document(restaurant.id).delete { err in
                if let err = err {
                    alertMessage = "Delete failed: \(err.localizedDescription)"
                    showAlert = true
                } else {
                    loadRestaurants()
                }
            }
        case .menuItem(let restaurant, let item):
            let dict: [String: Any] = [
                "id": item.id,
                "name": item.name,
                "price": item.price,
                "description": item.description,
                "isAvailable": item.isAvailable,
                "imageURL": item.imageURL as Any
            ]
            db.collection("restaurants").document(restaurant.id).updateData([
                "menuItems": FieldValue.arrayRemove([dict])
            ]) { err in
                if let err = err {
                    alertMessage = "Delete failed: \(err.localizedDescription)"
                    showAlert = true
                } else {
                    loadRestaurants()
                }
            }
        case .none:
            break
        }
        pendingDeletion = nil
    }
}

enum DeletionType {
    case restaurant(Restaurant)
    case menuItem(restaurant: Restaurant, item: MenuItem)
}

#Preview {
    AdminView()
}
