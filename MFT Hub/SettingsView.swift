import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @AppStorage("serverURL") private var serverURL = AppConfig.defaultServerURL
    @AppStorage("token") private var token = AppConfig.defaultToken

    @State private var goal = "2000"
    @State private var routines: [RoutineInput] = []
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("https://your-server.example.com", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Shared token", text: $token)
                    if !state.model.isEmpty {
                        LabeledContent("Model", value: state.model)
                    }
                }

                Section {
                    TextField("2000", text: $goal).keyboardType(.numberPad)
                } header: {
                    Text("Daily calorie budget")
                } footer: {
                    Text("How many calories you can eat per day. The home screen counts down what's left.")
                }

                Section {
                    ForEach(routines.indices, id: \.self) { i in
                        VStack(spacing: 6) {
                            TextField("Name (e.g. Morning coffee)", text: $routines[i].name)
                                .font(.callout.weight(.semibold))
                            TextField("What it is (e.g. oat latte, ~150 cal)", text: $routines[i].descr)
                                .font(.footnote).foregroundColor(.secondary)
                        }
                    }
                    .onDelete { routines.remove(atOffsets: $0) }
                    Button {
                        routines.append(RoutineInput(name: "", descr: ""))
                    } label: { Label("Add a routine food", systemImage: "plus") }
                } header: {
                    Text("Routine foods")
                } footer: {
                    Text("Define your usuals so “my normal morning coffee” just works.")
                }
            }
            .navigationTitle("Settings")
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { Task { await saveAll() } }.disabled(saving)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                goal = String(state.goal)
                routines = state.routines.map { RoutineInput(name: $0.name, descr: $0.descr) }
                if routines.isEmpty { routines = [RoutineInput(name: "Morning coffee", descr: "")] }
            }
        }
    }

    private func saveAll() async {
        saving = true
        defer { saving = false }
        // Persist goal + routines to the server (URL/token already saved via @AppStorage).
        if state.configured {
            if let g = Int(goal) { _ = try? await APIClient.setGoal(g) }
            let cleaned = routines.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
                                            || !$0.descr.trimmingCharacters(in: .whitespaces).isEmpty }
            _ = try? await APIClient.setRoutines(cleaned)
            await state.refresh()
        }
        dismiss()
    }
}
