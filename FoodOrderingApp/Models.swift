import Foundation

enum UserRole: String, Codable {
    case customer
    case admin
}

struct MenuItem: Identifiable, Codable, Equatable {
    let id: String = UUID().uuidString
    var name: String
    var price: Double
    var description: String
    var isAvailable: Bool
    var imageURL: String?
    
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CartItem: Identifiable {
    let id: String = UUID().uuidString
    let menuItem: MenuItem
    var quantity: Int
    let options: [String]
    let restaurantName: String
}

struct Order: Identifiable {
    let id: String = UUID().uuidString
    var items: [CartItem]
    var deliveryAddress: String
    var totalPrice: Double
    var status: String
    
    var deliveryFee: Double = 0.0
    var eta: Int = 0
}

struct Address: Codable, Equatable {
    var street: String
    var validated: Bool
    var eta: Int
    var fee: Double
    
    init() {
        self.street = ""
        self.validated = false
        self.eta = 0
        self.fee = 0.0
    }
    
    init(street: String, validated: Bool = false, eta: Int = 0, fee: Double = 0.0) {
        self.street = street
        self.validated = validated
        self.eta = eta
        self.fee = fee
    }
}

struct Restaurant: Identifiable, Hashable {
    let id: String
    let name: String
    let cuisine: String
    let rating: Double
    var menuItems: [MenuItem]
    let location: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Restaurant, rhs: Restaurant) -> Bool {
        lhs.id == rhs.id
    }
}
