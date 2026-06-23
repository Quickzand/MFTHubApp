import WidgetKit
import SwiftUI

// Personal single-user app: the server URL + token are baked in (same as the app's
// defaults). If you ever change them in the app, update them here too.
private let kServerURL = Secrets.serverURL
private let kToken = Secrets.token
private let kAccent = Color(red: 0.137, green: 0.820, blue: 0.514) // #23D183

struct TodayStat {
    var consumed: Double
    var goal: Int
    var remaining: Double
}

struct MFTEntry: TimelineEntry {
    let date: Date
    let stat: TodayStat?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MFTEntry {
        MFTEntry(date: Date(), stat: TodayStat(consumed: 1200, goal: 2000, remaining: 800))
    }

    func getSnapshot(in context: Context, completion: @escaping (MFTEntry) -> Void) {
        Task { completion(MFTEntry(date: Date(), stat: await fetch())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MFTEntry>) -> Void) {
        Task {
            let entry = MFTEntry(date: Date(), stat: await fetch())
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetch() async -> TodayStat? {
        guard let url = URL(string: kServerURL + "/today") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(kToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let consumed = (obj?["consumed"] as? NSNumber)?.doubleValue ?? 0
            let goal = (obj?["goal"] as? NSNumber)?.intValue ?? 2000
            let remaining = (obj?["remaining"] as? NSNumber)?.doubleValue ?? (Double(goal) - consumed)
            return TodayStat(consumed: consumed, goal: goal, remaining: remaining)
        } catch {
            return nil
        }
    }
}

/// A row of dots that fill left-to-right; the "current" dot fills partially,
/// so the whole row reads like a progress bar spread across dots.
struct DotsProgress: View {
    var progress: Double          // 0...1
    var count: Int = 10
    var dot: CGFloat = 9

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                let fill = min(1, max(0, progress * Double(count) - Double(i)))
                ZStack {
                    Circle().fill(Color.primary.opacity(0.22))   // empty
                    Circle().fill(kAccent)                       // filled portion
                        .mask(
                            GeometryReader { geo in
                                Rectangle().frame(width: geo.size.width * fill)
                            }
                        )
                }
                .frame(width: dot, height: dot)
            }
        }
    }
}

struct MFTWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MFTEntry

    private var remaining: Int { Int((entry.stat?.remaining ?? 0).rounded()) }
    private var consumed: Double { entry.stat?.consumed ?? 0 }
    private var goal: Int { entry.stat?.goal ?? 2000 }
    private var progress: Double { goal > 0 ? min(1, consumed / Double(goal)) : 0 }
    private var leftLabel: String { remaining >= 0 ? "left" : "over" }

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    Rectangle().fill(.fill.tertiary)
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) {
                Image(systemName: "fork.knife")
            } currentValueLabel: {
                Text("\(abs(remaining))")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(kAccent)

        case .accessoryInline:
            Text("\(abs(remaining)) Cal \(leftLabel)")

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 6) {
                Text("\(abs(remaining)) Cal \(leftLabel)").font(.headline)
                DotsProgress(progress: progress, count: 10, dot: 8)
            }

        default: // .systemSmall
            VStack(spacing: 7) {
                Text("\(abs(remaining))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(kAccent)
                Text("Cal \(leftLabel)").font(.caption).foregroundStyle(.secondary)
                DotsProgress(progress: progress, count: 10, dot: 9)
                Text("\(Int(consumed)) / \(goal)").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct MFTWidget: Widget {
    let kind = "MFTWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MFTWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Calories Left")
        .description("Your remaining calories today.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

@main
struct MFTWidgetBundle: WidgetBundle {
    var body: some Widget { MFTWidget() }
}
