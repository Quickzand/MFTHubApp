import SwiftUI

struct WeightHistorySheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Weight?
    @State private var editValue = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(state.weights.reversed()) { w in
                    HStack {
                        Text(displayDate(w))
                        Spacer()
                        Text("\(w.value, specifier: "%.1f") lb")
                            .fontWeight(.semibold).monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editValue = String(format: "%.1f", w.value)
                        editing = w
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Haptics.tap()
                            Task { await state.deleteWeight(w) }
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .overlay {
                if state.weights.isEmpty {
                    Text("No weights logged yet.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Weight history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .alert("Edit weight", isPresented: Binding(
                get: { editing != nil },
                set: { if !$0 { editing = nil } })) {
                TextField("Weight (lb)", text: $editValue).keyboardType(.decimalPad)
                Button("Save") {
                    if let w = editing, let v = Double(editValue) {
                        Haptics.success()
                        Task { await state.setWeight(date: w.date, value: v) }
                    }
                    editing = nil
                }
                Button("Cancel", role: .cancel) { editing = nil }
            } message: {
                Text(editing.map(displayDate) ?? "")
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.medium, .large])
    }

    private func displayDate(_ w: Weight) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d yyyy"
        return f.string(from: w.dayDate)
    }
}
