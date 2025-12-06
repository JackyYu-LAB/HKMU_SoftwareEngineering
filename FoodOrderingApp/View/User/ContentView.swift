import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import MapKit

struct ContentView: View {
    @State private var restaurants: [Restaurant] = []
    @State private var cart: [CartItem] = []
    @State private var address: Address = Address()
    @State private var orders: [Order] = []
    @State private var searchText: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showPayment: Bool = false
    @State private var couponCode: String = ""
    @State private var finalPaymentAmount: Double = 0.0
    @State private var paymentSuccess: Bool = false
    @State private var selectedOrder: Order? = nil
    @State private var rating: Int = 5
    @State private var review: String = ""
    @State private var selectedPendingOrder: Order? = nil
    @State private var selectedOrderForDetail: Order? = nil
    @State private var tabSelection: Int = 1
    @State private var alertTitle: String = ""
    
    
    let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            TabView(selection: $tabSelection) {
                menuView
                    .tabItem { 
                        Label("Menu", systemImage: "menucard.fill")
                    }
                    .tag(1)
                
                cartView
                    .tabItem { 
                        Label("Cart", systemImage: "cart.fill")
                    }
                    .tag(2)
                
                ordersView
                    .tabItem { 
                        Label("Orders", systemImage: "list.bullet.rectangle")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem { 
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(.orange)
            .onAppear {
                loadOrders()
                loadSavedAddress()
                
                if restaurants.isEmpty {
                    Task {
                        await loadRestaurantsFromFirebase()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {}
                
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showPayment) {
                paymentView
            }
        }
    }
    
    private var menuView: some View {
        VStack(spacing: 0) {
            // Modern Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                    
                    TextField("Search restaurants, dishes...", text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 8)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // Restaurant List
            ScrollView {
                LazyVStack(spacing: 20) {
                    if filteredRestaurants.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text(restaurants.isEmpty ? "Loading restaurants..." : "No restaurants found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if !restaurants.isEmpty {
                                Text("Try a different search term")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(filteredRestaurants) { restaurant in
                            RestaurantCardView(restaurant: restaurant, addToCart: addToCart)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .refreshable {
                await loadRestaurantsFromFirebase()
            }
            .onAppear {
                if restaurants.isEmpty {
                    Task {
                        await loadRestaurantsFromFirebase()
                    }
                }
            }
        }
    }
    
    private var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return restaurants
        } else {
            return restaurants.filter { restaurant in
                restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                restaurant.cuisine.localizedCaseInsensitiveContains(searchText) ||
                restaurant.menuItems.contains { item in
                    item.name.localizedCaseInsensitiveContains(searchText) ||
                    item.description.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    private func addToCart(item: MenuItem, restaurantName: String) {
        if let existingIndex = cart.firstIndex(where: { cartItem in
            cartItem.menuItem.id == item.id &&
            cartItem.restaurantName == restaurantName
        }) {
            cart[existingIndex].quantity += 1
        } else {
            cart.append(CartItem(menuItem: item, quantity: 1, options: [], restaurantName: restaurantName))
        }
    }
    
    private var cartView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Delivery Address Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text("Delivery Address")
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    HStack {
                        TextField("Enter address (e.g., Tsim Sha Tsui)", text: $address.street)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        Button(action: { validateAddress() }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(address.validated ? .green : .orange)
                        }
                        .disabled(address.street.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    if address.validated {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Address Verified")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text(address.street)
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("ETA: \(address.eta) min")
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("Delivery Fee: HK$\(address.fee, specifier: "%.2f")")
                                        .font(.subheadline)
                                }
                            }
                            .padding(.leading, 20)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Cart Items Section
                if cart.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cart")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Your cart is empty")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add items from the menu to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Order Items")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal, 16)
                        
                        ForEach($cart) { $item in
                            CartItemCardView(item: $item, cart: $cart)
                        }
                    }
                }
                
                // Coupon Section
                if !cart.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.orange)
                            Text("Coupon Code")
                                .font(.headline)
                        }
                        
                        TextField("Enter coupon code (optional)", text: $couponCode)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal, 16)
                }
                
                // Total and Checkout Button
                if !cart.isEmpty {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Subtotal")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("HK$\(cart.reduce(0) { $0 + ($1.menuItem.price * Double($1.quantity)) }, specifier: "%.2f")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Delivery Fee")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("HK$\(address.fee, specifier: "%.2f")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total")
                                    .font(.system(size: 20, weight: .bold))
                                Spacer()
                                Text("HK$\(totalPrice, specifier: "%.2f")")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        
                        Button(action: {
                            placeOrder()
                            showPayment = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Place Order")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: cartTotalItems > 0 && address.validated ? [Color.orange, Color.red] : [Color.gray, Color.gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: (cartTotalItems > 0 && address.validated ? Color.orange : Color.gray).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(cartTotalItems <= 0 || !address.validated)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var cartTotalItems: Int {
        cart.reduce(0) { $0 + $1.quantity }
    }
    
    private var totalPrice: Double {
        cart.reduce(0) { $0 + ($1.menuItem.price * Double($1.quantity)) } + address.fee
    }
    
    private func validateAddress() {
        let trimmed = address.street.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please enter a delivery address."
            showAlert = true
            return
        }
        calculateETA { eta in
            let fee = 10.0 + Double(eta) * 0.5
            address = Address(street: trimmed, validated: true, eta: eta, fee: fee)
            saveAddressToFirestore()
        }
    }
    
    private func calculateETA(completion: @escaping (Int) -> Void) {
        let geocoder = CLGeocoder()
        var userAddress = address.street.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !userAddress.localizedCaseInsensitiveContains("hong kong") {
            userAddress += ", Hong Kong"
        }
        
        geocoder.geocodeAddressString(userAddress) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
//                self.alertMessage = "Unable to locate address. Try adding 'Hong Kong' or using English."
//                self.showAlert = true
                completion(30)
                return
            }
            
            guard let userLocation = placemarks?.first?.location else {
//                self.alertMessage = "Address not found. Please check spelling or add 'Hong Kong'."
//                self.showAlert = true
                completion(30)
                return
            }
            if let firstRestaurant = restaurants.first {
                geocoder.geocodeAddressString(firstRestaurant.location) { placemarks, error in
                    guard let restaurantLocation = placemarks?.first?.location else {
//                        self.alertMessage = "Restaurant location error."
//                        self.showAlert = true
                        completion(30)
                        return
                    }

                    let distanceMeters = userLocation.distance(from: restaurantLocation)
                    let distanceKm = distanceMeters / 1000.0
                    let etaMinutes = Int((distanceKm / 30.0) * 60.0)
                    completion(max(etaMinutes, 15))
                }
            } else {
                completion(30)
            }
        }
    }
    
    private func placeOrder() {
        var orderTotal = totalPrice
        if !couponCode.trimmingCharacters(in: .whitespaces).isEmpty {
            orderTotal *= 0.9
        }
        finalPaymentAmount = orderTotal
        
        let newOrder = Order(
            items: cart,
            deliveryAddress: address.street,
            totalPrice: orderTotal,
            status: "pending",
            deliveryFee: address.fee,
            eta: address.eta          
        )
        orders.append(newOrder)
        saveOrdersToFirestore()
    }
    
    private func loadRestaurantsFromFirebase() async {
        do {
            let snapshot = try await db.collection("restaurants").getDocuments()
            var loaded: [Restaurant] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                let id = doc.documentID
                let name = data["name"] as? String ?? "Unknown Restaurant"
                let cuisine = data["cuisine"] as? String ?? ""
                let rating = data["rating"] as? Double ?? 4.5
                let location = data["location"] as? String ?? ""
                
                var menuItems: [MenuItem] = []
                
                if let itemsArray = data["menuItems"] as? [[String: Any]] {
                    for itemData in itemsArray {
                        let name = itemData["name"] as? String ?? ""
                        let priceRaw = itemData["price"] ?? 0.0
                        let price: Double = {
                            if let p = priceRaw as? Double { return p }
                            if let p = priceRaw as? Int { return Double(p) }
                            if let p = priceRaw as? String, let d = Double(p) { return d }
                            return 0.0
                        }()
                        let description = itemData["description"] as? String ?? ""
                        let isAvailable = itemData["isAvailable"] as? Bool ?? true
                        let imageURL = itemData["imageURL"] as? String
                        
                        let itemId = itemData["id"] as? String ?? UUID().uuidString
                        let menuItem = MenuItem(
                            name: name,
                            price: price,
                            description: description,
                            isAvailable: isAvailable,
                            imageURL: imageURL
                        )
                        menuItems.append(menuItem)
                    }
                }
                
                let restaurant = Restaurant(
                    id: id,
                    name: name,
                    cuisine: cuisine,
                    rating: rating,
                    menuItems: menuItems,
                    location: location
                )
                loaded.append(restaurant)
            }
            
            await MainActor.run {
                self.restaurants = []       
                self.restaurants = loaded
            }
            
        } catch {
            await MainActor.run {
                alertTitle = "Loading Failed"
                alertMessage = "Please check your network connection and try again after clicking the drop-down menu."
                showAlert = true
            }
        }
    }
    
    func loadOrders() {
        db.collection("orders").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Order Loading Error: \(error)")
                return
            }
            var loadedOrders: [Order] = []
            for document in querySnapshot?.documents ?? [] {
                let data = document.data()
                let id = document.documentID
                let deliveryAddress = data["deliveryAddress"] as? String ?? ""
                let totalPrice = data["totalPrice"] as? Double ?? 0.0
                let status = data["status"] as? String ?? "pending"
                var items: [CartItem] = []
                if let itemsData = data["items"] as? [[String: Any]] {
                    for itemData in itemsData {
                        let menuItem = MenuItem(
                            name: itemData["name"] as? String ?? "",
                            price: itemData["price"] as? Double ?? 0.0,
                            description: itemData["description"] as? String ?? "",
                            isAvailable: true,
                            imageURL: itemData["imageURL"] as? String
                        )
                        let cartItem = CartItem(
                            menuItem: menuItem,
                            quantity: itemData["quantity"] as? Int ?? 1,
                            options: itemData["options"] as? [String] ?? [],
                            restaurantName: itemData["restaurantName"] as? String ?? ""
                        )
                        items.append(cartItem)
                    }
                }
                loadedOrders.append(Order(items: items, deliveryAddress: deliveryAddress, totalPrice: totalPrice, status: status))
            }
            self.orders = loadedOrders
        }
    }
    
    func saveOrdersToFirestore() {
        for order in orders {
            db.collection("orders").document(order.id).setData([
                "deliveryAddress": order.deliveryAddress,
                "totalPrice": order.totalPrice,
                "status": order.status,
                "items": order.items.map { item in
                    [
                        "name": item.menuItem.name,
                        "price": item.menuItem.price,
                        "description": item.menuItem.description,
                        "imageURL": item.menuItem.imageURL ?? "",
                        "quantity": item.quantity,
                        "options": item.options,
                        "restaurantName": item.restaurantName
                    ]
                }
            ]) { error in
                if let error = error {
                    print("Order Saving Error: \(error)")
                }
            }
        }
    }
    
    private func loadSavedAddress() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Load Address Error: \(error)")
                return
            }
            if let data = snapshot?.data(), let savedStreet = data["savedAddress.street"] as? String {
                address = Address(street: savedStreet, validated: false, eta: 0, fee: 0.0)
            }
        }
    }
    
    private func saveAddressToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).updateData([
            "savedAddress.street": address.street
        ]) { error in
            if let error = error {
                print("Load Address Error: \(error)")
            }
        }
    }
    
    private var ordersView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if orders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No orders yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Your order history will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(orders) { order in
                        OrderCardView(order: order) {
                            selectedOrderForDetail = order
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedOrderForDetail) { order in
            OrderDetailView(order: order,
                            onPay: {
                selectedPendingOrder = order
                showPayment = true
            })
        }
    }
    
    private func submitReview(for order: Order) {
        print("Review submitted for order \(order.id): \(rating) stars – \(review)")
    }
    
    private var paymentView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Payment")
                            .font(.system(size: 28, weight: .bold))
                    }
                    .padding(.top, 20)
                    
                    // Order Summary
                    if let order = selectedPendingOrder ?? orders.last(where: { $0.status == "pending" }) {
                        let subtotal = order.items.reduce(0.0) { $0 + ($1.menuItem.price * Double($1.quantity)) }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Order Summary")
                                .font(.headline)
                                .padding(.horizontal, 16)
                            
                            ForEach(order.items) { item in
                                HStack(spacing: 12) {
                                    Group {
                                        if let url = item.menuItem.imageURL, let imageURL = URL(string: url) {
                                            AsyncImage(url: imageURL) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                        .frame(width: 50, height: 50)
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                case .failure:
                                                    Image(systemName: "photo")
                                                        .foregroundColor(.gray)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        } else {
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray.opacity(0.5))
                                                .font(.system(size: 18))
                                        }
                                    }
                                    .frame(width: 50, height: 50)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .clipped()
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.menuItem.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("Qty: \(item.quantity) × HK$\(item.menuItem.price, specifier: "%.2f")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("HK$\(item.menuItem.price * Double(item.quantity), specifier: "%.2f")")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.orange)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                                .padding(.horizontal, 16)
                            }
                            
                            // Price Breakdown
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Subtotal")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("HK$\(subtotal, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Delivery Fee")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("HK$\(order.deliveryFee, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Total")
                                        .font(.system(size: 20, weight: .bold))
                                    Spacer()
                                    Text("HK$\(order.totalPrice, specifier: "%.2f")")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6).opacity(0.5))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        
                        // Payment Button
                        VStack(spacing: 16) {
                            Button(action: {
                                paymentSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    payForPendingOrder()
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    if paymentSuccess {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(paymentSuccess ? "Processing..." : "Confirm Payment")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: paymentSuccess ? [Color.gray, Color.gray] : [Color.orange, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: (paymentSuccess ? Color.gray : Color.orange).opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(paymentSuccess)
                            .padding(.horizontal, 16)
                            
                            if paymentSuccess {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Payment Successful!")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 20)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Order Not Found")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Unable to find order awaiting payment")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                dismissPaymentAndResetAll()
            }
        }
    }
    
    private func onSuccess() {
        if let lastIndex = orders.indices.last {
            orders[lastIndex].status = "paid"
            saveOrdersToFirestore()
        }
        dismissPaymentAndResetAll()
        alertTitle = "Success"
        alertMessage = "Order placed successfully! Thank you for your purchase."
        showAlert = true
    }
    
    private func payForPendingOrder() {
        if let pendingOrder = selectedPendingOrder,
           let index = orders.firstIndex(where: { $0.id == pendingOrder.id }) {
            orders[index].status = "paid"
            saveOrdersToFirestore()
        }
        else if let lastIndex = orders.indices.last {
            orders[lastIndex].status = "paid"
            saveOrdersToFirestore()
        }

        dismissPaymentAndResetAll()
        alertTitle = "Success"
        alertMessage = "Payment successful! Your order is now paid."
        showAlert = true
    }
    
    private func dismissPaymentAndResetAll() {
        tabSelection = 3
        cart.removeAll()
        couponCode = ""
        selectedPendingOrder = nil
        paymentSuccess = false
        finalPaymentAmount = 0.0
        showPayment = false
        address = Address()
    }
}

struct CartItemCardView: View {
    @Binding var item: CartItem
    @Binding var cart: [CartItem]
    
    var body: some View {
        HStack(spacing: 12) {
            // Item Image
            Group {
                if let url = item.menuItem.imageURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 70, height: 70)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.system(size: 25))
                }
            }
            .frame(width: 70, height: 70)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .clipped()
            
            // Item Details
            VStack(alignment: .leading, spacing: 6) {
                Text(item.restaurantName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.menuItem.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack {
                    Text("HK$\(item.menuItem.price, specifier: "%.2f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("× \(item.quantity)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("HK$\(item.menuItem.price * Double(item.quantity), specifier: "%.2f")")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            
            // Quantity Controls
            VStack(spacing: 4) {
                Button(action: {
                    withAnimation {
                        if let index = cart.firstIndex(where: { $0.id == item.id }) {
                            var updatedItem = item
                            updatedItem.quantity += 1
                            cart[index] = updatedItem
                        }
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
                
                Text("\(item.quantity)")
                    .font(.headline)
                    .frame(minWidth: 30)
                
                Button(action: {
                    withAnimation {
                        if let index = cart.firstIndex(where: { $0.id == item.id }) {
                            var updatedItem = item
                            updatedItem.quantity = max(0, updatedItem.quantity - 1)
                            if updatedItem.quantity == 0 {
                                cart.remove(at: index)
                            } else {
                                cart[index] = updatedItem
                            }
                        }
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .padding(.horizontal, 16)
    }
}

struct OrderCardView: View {
    let order: Order
    let onTap: () -> Void
    
    var statusColor: Color {
        switch order.status.lowercased() {
        case "paid":
            return .green
        case "pending":
            return .orange
        case "completed":
            return .blue
        default:
            return .gray
        }
    }
    
    var statusIcon: String {
        switch order.status.lowercased() {
        case "paid":
            return "checkmark.circle.fill"
        case "pending":
            return "clock.fill"
        case "completed":
            return "checkmark.seal.fill"
        default:
            return "circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id.prefix(8))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(order.items.count) item\(order.items.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.caption)
                    Text(order.status.capitalized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15))
                .cornerRadius(20)
            }
            
            Divider()
            
            // Order Items Preview
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(order.items.prefix(2))) { item in
                    HStack {
                        Text("• \(item.menuItem.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("×\(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if order.items.count > 2 {
                    Text("+ \(order.items.count - 2) more item\(order.items.count - 2 == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Divider()
            
            // Total
            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text("HK$\(order.totalPrice, specifier: "%.2f")")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ContentView()
}
