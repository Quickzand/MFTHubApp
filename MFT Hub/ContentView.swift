import SwiftUI
import UIKit
import Charts

struct ContentView: View {
    @EnvironmentObject var state: AppState

    @State private var text = ""
    @State private var image: UIImage?
    @State private var showSettings = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showPhotoChoice = false
    @State private var estimating = false
    @State private var deepSearch = false
    @State private var pending: Estimate?
    @State private var pendingText = ""
    @State private var editing: Entry?
    @State private var showWeightInput = false
    @State private var showWeightHistory = false
    @State private var weightInput = ""
    @State private var recentlyDeleted: Entry?
    @FocusState private var inputFocused: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    dateNav
                    summaryCard
                    weekChartCard
                    weightCard
                    entriesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(background)
            .navigationTitle("MFT Hub")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
            .refreshable { await state.refresh() }
        }
        .tint(Theme.accent)
        .task { await state.refresh() }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(state) }
        .sheet(isPresented: $showWeightHistory) { WeightHistorySheet().environmentObject(state) }
        .sheet(isPresented: $showCamera) { ImagePicker(source: .camera) { image = $0 } }
        .sheet(isPresented: $showLibrary) { ImagePicker(source: .library) { image = $0 } }
        .sheet(item: $pending) { est in
            EstimateSheet(estimate: est, description: pendingText) { create in
                Task { await state.save(create); Haptics.success(); reset() }
            } onDiscard: { pending = nil }
        }
        .sheet(item: $editing) { entry in
            EditEntrySheet(entry: entry) { updated in
                Task { await state.update(updated) }
            } onSaveRoutine: { name, descr in
                Task { await state.addRoutine(name: name, descr: descr) }
            } onRelog: {
                Task { await state.relog(entry) }
            }
        }
        .confirmationDialog("Add a photo", isPresented: $showPhotoChoice) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Library") { showLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Log weight", isPresented: $showWeightInput) {
            TextField("Weight (lb)", text: $weightInput).keyboardType(.decimalPad)
            Button("Save") {
                if let v = Double(weightInput) { Task { await state.logWeight(v); Haptics.success() } }
                weightInput = ""
            }
            Button("Cancel", role: .cancel) { weightInput = "" }
        } message: { Text("Enter today's weight.") }
        .alert("Something went wrong",
               isPresented: Binding(get: { state.errorMessage != nil },
                                    set: { if !$0 { state.errorMessage = nil } })) {
            Button("OK", role: .cancel) { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
    }

    private var background: some View {
        let colors: [Color] = scheme == .dark
            ? [Color(red: 0.04, green: 0.19, blue: 0.12),
               Color(red: 0.05, green: 0.10, blue: 0.09), .black]
            : [Color(red: 0.85, green: 0.93, blue: 0.85),
               Color(red: 0.95, green: 0.97, blue: 0.95),
               Color(red: 0.98, green: 0.99, blue: 0.98)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottom).ignoresSafeArea()
    }

    private var progress: Double { state.goal > 0 ? min(1, state.totalCalories / Double(state.goal)) : 0 }
    private var over: Bool { state.totalCalories > Double(state.goal) }
    private var remaining: Int { state.goal - Int(state.totalCalories.rounded()) }

    private var displayedEntries: [Entry] {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; f.locale = Locale(identifier: "en_US_POSIX")
        return state.entries.sorted {
            (f.date(from: $0.time) ?? .distantPast) > (f.date(from: $1.time) ?? .distantPast)
        }
    }

    private var dateNav: some View {
        HStack {
            Button { state.goToDay(-1) } label: { Image(systemName: "chevron.left").font(.headline) }
            Spacer()
            Text(dateTitle).font(.headline)
            Spacer()
            Button { state.goToDay(1) } label: { Image(systemName: "chevron.right").font(.headline) }
                .disabled(state.isToday).opacity(state.isToday ? 0.3 : 1)
        }
        .tint(.primary).padding(.horizontal, 8)
    }
    private var dateTitle: String {
        if state.isToday { return "Today" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: state.selectedDate)
    }

    private var summaryCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.10), lineWidth: 16)
                Circle().trim(from: 0, to: progress)
                    .stroke(over ? Theme.over : Theme.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90)).animation(.easeOut(duration: 0.5), value: progress)
                VStack(spacing: 2) {
                    Text("\(abs(remaining))").font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(over ? Theme.over : .primary)
                    Text(remaining >= 0 ? "Cal left" : "Cal over").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(width: 196, height: 196).padding(.top, 4)
            Text("\(Int(state.totalCalories)) eaten · \(state.goal) goal").font(.footnote).foregroundStyle(.secondary)
            HStack {
                macro("Protein", state.totalProtein)
                Divider().frame(height: 30)
                macro("Carbs", state.totalCarbs)
                Divider().frame(height: 30)
                macro("Fat", state.totalFat)
            }
        }
        .padding(24).frame(maxWidth: .infinity)
        .glassEffect(in: RoundedRectangle(cornerRadius: 30))
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .onTapGesture { showSettings = true }
    }
    private func macro(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(value))g").font(.title3.weight(.semibold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private var weekChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Last 7 days").font(.headline)
            Chart {
                ForEach(state.weekData) { d in
                    BarMark(x: .value("Day", d.dayDate, unit: .day), y: .value("Cal", d.calories))
                        .foregroundStyle(Theme.accent.gradient).cornerRadius(6)
                }
                RuleMark(y: .value("Goal", Double(state.goal)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(.secondary)
            }
            .frame(height: 150)
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 28))
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight").font(.headline)
                Spacer()
                if !state.weights.isEmpty {
                    Button { showWeightHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath").font(.subheadline)
                    }
                    .buttonStyle(.glass).tint(.primary)
                }
                Button { showWeightInput = true } label: { Label("Log", systemImage: "plus").font(.subheadline) }
                    .buttonStyle(.glass).tint(.primary)
            }
            if let latest = state.latestWeight {
                Text("\(latest.value, specifier: "%.1f") lb").font(.system(size: 30, weight: .bold, design: .rounded))
            } else {
                Text("No weight logged yet — tap Log.").font(.subheadline).foregroundStyle(.secondary)
            }
            if state.weights.count >= 2 {
                Chart(state.weights) { w in
                    LineMark(x: .value("Date", w.dayDate), y: .value("lb", w.value))
                        .interpolationMethod(.catmullRom).foregroundStyle(Theme.accent)
                    PointMark(x: .value("Date", w.dayDate), y: .value("lb", w.value)).foregroundStyle(Theme.accent)
                }
                .frame(height: 110).chartYScale(domain: .automatic(includesZero: false))
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 28))
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.isToday ? "Today" : "Entries").font(.title3.weight(.semibold)).padding(.leading, 4).padding(.top, 4)
            if state.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Nothing logged").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ForEach(displayedEntries) { e in entryRow(e) }
            }
        }
    }

    private func entryRow(_ e: Entry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(e.text).font(.callout.weight(.medium))
                Text("\(e.time)  ·  P \(Int(e.protein))  C \(Int(e.carbs))  F \(Int(e.fat))").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("\(Int(e.calories))").font(.headline.weight(.semibold).monospacedDigit())
                + Text(" Cal").font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { editing = e }
        .contextMenu {
            Button {
                Haptics.success()
                Task { await state.relog(e) }
            } label: { Label("Log again today", systemImage: "arrow.counterclockwise") }
            Button(role: .destructive) { deleteEntry(e) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if estimating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(deepSearch ? "Researching your meal…" : "Analyzing your meal…")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }.padding(.horizontal, 6)
            }
            if let d = recentlyDeleted {
                HStack {
                    Text("Deleted").foregroundStyle(.secondary)
                    Text(d.text).lineLimit(1)
                    Spacer()
                    Button("Undo") { undoDelete() }.font(.subheadline.weight(.semibold))
                }.font(.subheadline).padding(12).glassEffect(in: RoundedRectangle(cornerRadius: 16))
            }
            if !state.routines.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.routines) { r in
                            Button(r.name) { text = text.isEmpty ? r.name : text + ", " + r.name }
                                .font(.subheadline).tint(.primary).buttonStyle(.glass)
                        }
                    }.padding(.horizontal, 4)
                }
            }
            if let image {
                HStack(spacing: 12) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photo attached").font(.subheadline.weight(.semibold))
                        Text("Add a note if you want, then tap the green button.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Button { self.image = nil } label: { Image(systemName: "xmark.circle.fill").font(.title2) }.tint(.secondary)
                }.padding(10).glassEffect(in: RoundedRectangle(cornerRadius: 18))
            }
            HStack(spacing: 10) {
                Button { showPhotoChoice = true } label: { Image(systemName: "camera.fill").font(.body) }.buttonStyle(.glass)
                Button {
                    Haptics.tap()
                    deepSearch.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .fontWeight(deepSearch ? .bold : .regular)
                }
                .buttonStyle(.glass)
                .tint(deepSearch ? Theme.accent : .primary)
                TextField(image == nil ? "What did you eat?" : "Add a note (optional)", text: $text)
                    .focused($inputFocused).submitLabel(.done).onSubmit { inputFocused = false }
                    .padding(.horizontal, 16).padding(.vertical, 11).glassEffect(in: Capsule())
                Button(action: runEstimate) {
                    if estimating { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.up").font(.headline.weight(.bold)) }
                }.buttonStyle(.glassProminent).disabled(estimating || (text.isEmpty && image == nil))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func runEstimate() {
        inputFocused = false; estimating = true; pendingText = text
        let b64 = image?.compressedBase64()
        Task {
            do {
                let est = try await APIClient.estimate(text: text.isEmpty ? nil : text, imageBase64: b64,
                                                       research: deepSearch)
                pending = est
            } catch { state.errorMessage = error.localizedDescription }
            estimating = false
        }
    }
    private func deleteEntry(_ e: Entry) {
        Haptics.tap()
        withAnimation { recentlyDeleted = e }
        Task { await state.delete(e) }
        let captured = e
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if recentlyDeleted?.id == captured.id { withAnimation { recentlyDeleted = nil } }
        }
    }
    private func undoDelete() {
        guard let d = recentlyDeleted else { return }
        withAnimation { recentlyDeleted = nil }
        Task { await state.save(EntryCreate(text: d.text, calories: d.calories, protein: d.protein, carbs: d.carbs, fat: d.fat)) }
    }
    private func reset() { text = ""; image = nil; pending = nil; pendingText = ""; deepSearch = false }
}

extension Estimate: Identifiable {
    var id: String { "\(totalCalories)-\(items.count)-\(note.hashValue)" }
}
