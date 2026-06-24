import SwiftUI

struct EditEntrySheet: View {
    let entry: Entry
    let onSave: (Entry) -> Void
    let onSaveRoutine: (_ name: String, _ descr: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var showRoutinePrompt = false
    @State private var routineName = ""
    @State private var routineSaved = false

    init(entry: Entry,
         onSave: @escaping (Entry) -> Void,
         onSaveRoutine: @escaping (String, String) -> Void) {
        self.entry = entry
        self.onSave = onSave
        self.onSaveRoutine = onSaveRoutine
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
                        TextField("Cal", value: $calories, format: .number)
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
                Section {
                    Button {
                        routineName = text
                        showRoutinePrompt = true
                    } label: {
                        Label(routineSaved ? "Saved to routine foods" : "Save as routine food",
                              systemImage: routineSaved ? "checkmark.circle.fill" : "star")
                    }
                    .disabled(routineSaved)
                } footer: {
                    Text("Adds this as a quick “usual” you can tap when logging.")
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
            .alert("Save as routine", isPresented: $showRoutinePrompt) {
                TextField("Name", text: $routineName)
                Button("Save") {
                    let name = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    onSaveRoutine(name, text)
                    routineSaved = true
                    Haptics.success()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pick a short name for the chip — the full description is what the estimate uses.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
