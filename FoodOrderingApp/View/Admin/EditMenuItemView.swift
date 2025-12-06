// EditMenuItemView.swift
import SwiftUI
import FirebaseFirestore

struct EditMenuItemView: View {
    @Environment(\.dismiss) private var dismiss
    
    let restaurant: Restaurant
    @State var item: MenuItem         
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Dish Name", text: $item.name)
                TextField("Price", value: $item.price, format: .number)
                TextField("Description", text: $item.description)
                TextField("Image URL (optional)", text: Binding(
                    get: { item.imageURL ?? "" },
                    set: { item.imageURL = $0.isEmpty ? nil : $0 }
                ))
                Toggle("Available", isOn: $item.isAvailable)
            }
            .navigationTitle("Edit Dish")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await AdminView.updateMenuItem(
                                in: restaurant,
                                updatedItem: item,
                                onComplete: {
                                    onSave()
                                    dismiss()
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    init(restaurant: Restaurant, item: MenuItem, onSave: @escaping () -> Void) {
        self.restaurant = restaurant
        self._item = State(initialValue: item)
        self.onSave = onSave
    }
}
