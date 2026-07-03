import Foundation
import SwiftUI
import Combine
import WidgetKit

@MainActor
final class AppState: ObservableObject {
    @Published var entries: [Entry] = []
    @Published var routines: [Routine] = []
    @Published var weekData: [DaySummary] = []
    @Published var weights: [Weight] = []
    @Published var goal: Int = 2000
    @Published var model: String = ""
    @Published var selectedDate = Date()
    @Published var errorMessage: String?

    private let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    var dateString: String { df.string(from: selectedDate) }
    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    var nowTime: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: Date())
    }

    var totalCalories: Double { entries.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { entries.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }
    var latestWeight: Weight? { weights.last }
    var configured: Bool { !APIClient.baseURL.isEmpty && !APIClient.token.isEmpty }

    func refresh() async {
        guard configured else { return }
        do {
            async let e = APIClient.entries(date: dateString)
            async let r = APIClient.routines()
            async let s = APIClient.settings()
            async let wk = APIClient.summary(days: 7)
            async let wt = APIClient.weights(days: 90)
            entries = try await e
            routines = try await r
            let settings = try await s
            goal = settings.goal
            model = settings.model
            weekData = try await wk
            weights = try await wt
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEntries() async {
        guard configured else { return }
        do { entries = try await APIClient.entries(date: dateString) }
        catch { errorMessage = error.localizedDescription }
    }

    func goToDay(_ offset: Int) {
        guard let d = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        if Calendar.current.startOfDay(for: d) > Calendar.current.startOfDay(for: Date()) { return }
        selectedDate = d
        Task { await loadEntries() }
    }

    private func reloadWeek() async {
        weekData = (try? await APIClient.summary(days: 7)) ?? weekData
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Re-log an existing entry as a new entry for TODAY (even when viewing a
    /// past day) — same macros, no AI round-trip.
    func relog(_ entry: Entry) async {
        var c = EntryCreate(text: entry.text, calories: entry.calories,
                            protein: entry.protein, carbs: entry.carbs, fat: entry.fat)
        c.date = df.string(from: Date())
        c.time = nowTime
        do {
            let saved = try await APIClient.addEntry(c)
            if isToday { entries.append(saved) }
            await reloadWeek()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(_ create: EntryCreate) async {
        var c = create
        c.date = dateString
        c.time = nowTime
        do {
            let saved = try await APIClient.addEntry(c)
            entries.append(saved)
            await reloadWeek()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(_ entry: Entry) async {
        do {
            let saved = try await APIClient.updateEntry(
                id: entry.id,
                EntryCreate(text: entry.text, calories: entry.calories,
                            protein: entry.protein, carbs: entry.carbs, fat: entry.fat))
            if let i = entries.firstIndex(where: { $0.id == saved.id }) { entries[i] = saved }
            await reloadWeek()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ entry: Entry) async {
        let backup = entries
        entries.removeAll { $0.id == entry.id }
        do { try await APIClient.deleteEntry(id: entry.id); await reloadWeek() }
        catch { entries = backup; errorMessage = error.localizedDescription }
    }

    func addRoutine(name: String, descr: String) async {
        var inputs = routines.map { RoutineInput(name: $0.name, descr: $0.descr) }
        inputs.append(RoutineInput(name: name, descr: descr))
        do { routines = try await APIClient.setRoutines(inputs) }
        catch { errorMessage = error.localizedDescription }
    }

    func logWeight(_ value: Double) async {
        await setWeight(date: df.string(from: Date()), value: value)
    }

    /// Create or correct the weigh-in for a given date (weights are keyed by date).
    func setWeight(date: String, value: Double) async {
        do {
            let w = try await APIClient.logWeight(value: value, date: date)
            if let i = weights.firstIndex(where: { $0.date == w.date }) { weights[i] = w }
            else { weights.append(w); weights.sort { $0.date < $1.date } }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteWeight(_ w: Weight) async {
        let backup = weights
        weights.removeAll { $0.date == w.date }
        do { try await APIClient.deleteWeight(date: w.date) }
        catch { weights = backup; errorMessage = error.localizedDescription }
    }
}
