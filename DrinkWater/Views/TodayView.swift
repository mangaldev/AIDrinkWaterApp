import SwiftUI

/// Today's count, a button to log a glass on camera, and today's entries.
struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var log: DrinkLog
    @State private var showCamera = false

    private var todays: [DrinkEvent] { log.entries(on: Date()) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                        Text("\(log.drankCount(on: Date()))")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                        Text(log.drankCount(on: Date()) == 1 ? "glass today" : "glasses today")
                            .foregroundStyle(.secondary)
                        let missed = log.missedCount(on: Date())
                        if missed > 0 {
                            Text("\(missed) missed").font(.footnote).foregroundStyle(.red)
                        }
                        Button {
                            showCamera = true
                        } label: {
                            Label("Add a glass", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Today") {
                    if todays.isEmpty {
                        Text("Nothing logged yet").foregroundStyle(.secondary)
                    }
                    ForEach(todays) { EventRow(event: $0) }
                        .onDelete { idx in idx.map { todays[$0] }.forEach(log.delete) }
                }
            }
            .navigationTitle("WaterSipAI")
            .fullScreenCover(isPresented: $showCamera) {
                DrinkCheckView(mode: .manual) { showCamera = false }
                    .environmentObject(model)
            }
        }
    }
}

struct EventRow: View {
    let event: DrinkEvent

    var body: some View {
        HStack {
            Image(systemName: event.kind == .drank ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(event.kind == .drank ? .blue : .red)
            VStack(alignment: .leading) {
                Text(event.kind == .drank ? "Drank a glass" : "Missed (skipped)")
                Text(event.source == .manual ? "Added by you" : "Reminder")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.date, format: .dateTime.hour().minute())
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
