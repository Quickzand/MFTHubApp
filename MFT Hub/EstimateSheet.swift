import SwiftUI

struct EstimateSheet: View {
    let estimate: Estimate
    let description: String
    let onSave: (EntryCreate) -> Void
    let onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var calories: Double

    init(estimate: Estimate, description: String,
         onSave: @escaping (EntryCreate) -> Void, onDiscard: @escaping () -> Void) {
        self.estimate = estimate
        self.description = description
        self.onSave = onSave
        self.onDiscard = onDiscard
        _calories = State(initialValue: estimate.totalCalories)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(Int(calories)) kcal").font(.system(size: 32, weight: .heavy))

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(estimate.items, id: \.self) { item in
                            HStack(alignment: .top) {
                                Text(item.quantity.isEmpty ? item.name : "\(item.name) (\(item.quantity))")
                                Spacer()
                                Text("\(Int(item.calories)) kcal").foregroundColor(.secondary)
                            }.font(.subheadline)
                        }
                    }
                    if !estimate.note.isEmpty {
                        Text(estimate.note).font(.footnote).italic().foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Adjust total")
                        Spacer()
                        TextField("kcal", value: $calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .font(.subheadline)

                    HStack(spacing: 12) {
                        Button("Discard") { onDiscard(); dismiss() }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.glass)
                        Button("Save to log") {
                            onSave(EntryCreate(
                                text: description.isEmpty
                                    ? estimate.items.map(\.name).joined(separator: ", ")
                                    : description,
                                calories: calories,
                                protein: estimate.totalProteinG,
                                carbs: estimate.totalCarbsG,
                                fat: estimate.totalFatG))
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.glassProminent)
                        .tint(Theme.accent)
                    }
                    .controlSize(.large)
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .navigationTitle("Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
        }
        .presentationDetents([.medium, .large])
    }
}
