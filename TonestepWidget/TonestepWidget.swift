import WidgetKit
import SwiftUI

// MARK: - Shared data key constants (mirrors UserProfileStore's widget writes)
private enum WidgetKey {
    static let streak = "widget_streak"
    static let xp = "widget_xp"
    static let levelName = "widget_levelName"
    static let levelProgress = "widget_levelProgress"
    static let todayDone = "widget_todayDone"
    static let suiteName = "group.com.yugansh.Tonestep"
}

// MARK: - Timeline entry

struct TonestepEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let levelName: String
    let xp: Int
    let levelProgress: Double
    let todayDone: Bool
}

// MARK: - Provider

struct TonestepProvider: TimelineProvider {
    func placeholder(in context: Context) -> TonestepEntry {
        TonestepEntry(date: Date(), streak: 7, levelName: "Chord Finder", xp: 950, levelProgress: 0.6, todayDone: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TonestepEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonestepEntry>) -> Void) {
        let entry = currentEntry()
        let nextMidnight = Calendar.current.nextDate(after: Date(),
            matching: DateComponents(hour: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func currentEntry() -> TonestepEntry {
        let ud = UserDefaults(suiteName: WidgetKey.suiteName) ?? .standard
        return TonestepEntry(
            date: Date(),
            streak: ud.integer(forKey: WidgetKey.streak),
            levelName: ud.string(forKey: WidgetKey.levelName) ?? "Tone Seeker",
            xp: ud.integer(forKey: WidgetKey.xp),
            levelProgress: ud.double(forKey: WidgetKey.levelProgress),
            todayDone: ud.bool(forKey: WidgetKey.todayDone)
        )
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: TonestepEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red:0.36,green:0.10,blue:0.85), Color(red:0.18,green:0.04,blue:0.60)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "ear.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Tonestep")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    if entry.todayDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 28))
                    Text("\(entry.streak)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("day streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                // Level progress bar
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.levelName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white.opacity(0.2)).frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(.white)
                                .frame(width: geo.size.width * entry.levelProgress, height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(14)
        }
        .widgetURL(URL(string: "tonestep://today"))
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: TonestepEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red:0.36,green:0.10,blue:0.85), Color(red:0.18,green:0.04,blue:0.60)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            HStack(spacing: 0) {
                // Left: streak + level
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "ear.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                        Text("Tonestep").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("🔥")
                        Text("\(entry.streak)")
                            .font(.system(size: 48, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                    Text("day streak").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.levelName)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.2)).frame(height: 5)
                                RoundedRectangle(cornerRadius: 3).fill(.white)
                                    .frame(width: geo.size.width * entry.levelProgress, height: 5)
                            }
                        }
                        .frame(height: 5)
                        Text("\(entry.xp) XP").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(14)

                Divider().background(.white.opacity(0.2)).padding(.vertical, 12)

                // Right: CTA
                VStack(spacing: 10) {
                    Spacer()

                    if entry.todayDone {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32)).foregroundStyle(.green)
                            Text("Done!").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Text("See you tomorrow").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().fill(.white.opacity(0.15)).frame(width: 52, height: 52)
                                Image(systemName: "play.fill").font(.system(size: 22)).foregroundStyle(.white)
                            }
                            Text("Train Now").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Text("Keep your streak!").font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(14)
            }
        }
        .widgetURL(URL(string: "tonestep://today"))
    }
}

// MARK: - Widget definition

struct TonestepWidget: Widget {
    let kind = "TonestepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TonestepProvider()) { entry in
            if #available(iOS 17.0, *) {
                Group {
                    switch WidgetFamily.systemSmall == WidgetFamily.systemSmall {
                    default: SmallWidgetView(entry: entry)
                    }
                }
                .containerBackground(for: .widget) { Color.clear }
            } else {
                SmallWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Tonestep Streak")
        .description("Your daily streak and level at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry point

@main
struct TonestepWidgetBundle: WidgetBundle {
    var body: some Widget { TonestepWidget() }
}
