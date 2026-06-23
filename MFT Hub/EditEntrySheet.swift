import SwiftUI

struct EditEntrySheet: View {
    let entry: Entry
    let onSave: (Entry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double

    init(entry: Entry, onSave: @escaping (Entry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _text = State(initialValue: entry.text)
        _calories = State(initialValue: entry.calories)
        _protein = State(initialValue: entry.protein)
        _carbs = State(initialValue: entry.carbs)
        _fat = State(initialValue: entry.fat)
    }

    private func macroRow(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Description") {
                    TextField("What you ate", text: $text, axis: .vertical)
                }
                Section("Calories") {
                    HStack {
                        Text("Total")
                        Spacer()
                        TextField("kcal", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                Section("Macros (g)") {
                    macroRow("Protein", $protein)
                    macroRow("Carbs", $carbs)
                    macroRow("Fat", $fat)
                }
            }
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        var e = entry
                        e.text = text; e.calories = calories
                        e.protein = protein; e.carbs = carbs; e.fat = fat
                        onSave(e)
                        dismiss()
                    }.bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
