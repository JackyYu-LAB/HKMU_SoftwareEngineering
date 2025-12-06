import SwiftUI
import FirebaseFirestore


struct OrderDetailView: View {
    let order: Order
    let onPay: () -> Void
    
    private var subtotal: Double {
        order.items.reduce(0) { $0 + ($1.menuItem.price * Double($1.quantity)) }
    }
    
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Banner
                    HStack {
                        Image(systemName: order.status == "pending" ? "clock.fill" : "checkmark.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Order Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(order.status.capitalized)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .foregroundColor(statusColor)
                    .padding()
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Delivery Address Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.orange)
                            Text("Delivery Address")
                                .font(.headline)
                        }
                        
                        Text(order.deliveryAddress)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    // Order Items Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Order Items")
                            .font(.headline)
                            .padding(.horizontal, 16)
                        
                        ForEach(order.items) { item in
                            HStack(spacing: 12) {
                                // Item Image
                                Group {
                                    if let url = item.menuItem.imageURL, let imageURL = URL(string: url) {
                                        AsyncImage(url: imageURL) { phase in
                                            switch phase {
                                            case .empty:
                                                ProgressView()
                                                    .frame(width: 60, height: 60)
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
                                            .font(.system(size: 20))
                                    }
                                }
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .clipped()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.menuItem.name)
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    if !item.menuItem.description.isEmpty {
                                        Text(item.menuItem.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    HStack {
                                        Text("HK$\(item.menuItem.price, specifier: "%.2f")")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("× \(item.quantity)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("HK$\(item.menuItem.price * Double(item.quantity), specifier: "%.2f")")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
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
                    
                    // Price Summary Section
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
                    
                    // Payment Button
                    if order.status == "pending" {
                        Button(action: {
                            onPay()
                        }) {
                            HStack {
                                Spacer()
                                Text("Proceed to Payment")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
