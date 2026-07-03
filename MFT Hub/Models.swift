import Foundation

// MARK: - Wire models (match the FastAPI server)

struct Entry: Codable, Identifiable, Hashable {
    let id: String
    var date: String
    var time: String
    var text: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct EntryCreate: Codable {
    var text: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var date: String? = nil   // device-local YYYY-MM-DD, so meals count for the user's day
    var time: String? = nil   // device-local display time
}

struct EstimateItem: Codable, Hashable {
    var name: String
    var quantity: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
}

struct Estimate: Codable {
    var items: [EstimateItem]
    var totalCalories: Double
    var totalProteinG: Double
    var totalCarbsG: Double
    var totalFatG: Double
    var note: String
}

struct EstimateRequest: Codable {
    var text: String?
    var imageBase64: String?
    var mediaType: String?
}

struct Routine: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var descr: String
}

struct RoutineInput: Codable {
    var name: String
    var descr: String
}

struct Settings: Codable {
    var goal: Int
    var model: String
}

struct SettingsUpdate: Codable {
    var goal: Int
}

struct DaySummary: Codable, Identifiable {
    var date: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var id: String { date }
    var dayDate: Date { DateFormatters.ymd.date(from: date) ?? Date() }
}

struct Weight: Codable, Identifiable {
    var date: String
    var value: Double
    var id: String { date }
    var dayDate: Date { DateFormatters.ymd.date(from: date) ?? Date() }
}

enum DateFormatters {
    static let ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
}
