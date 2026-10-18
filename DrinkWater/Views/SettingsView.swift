import SwiftUI
#if SCREEN_TIME
import FamilyControls
#endif

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("showDetectionDebug") private var showDebug = false
    #if SCREEN_TIME
    @State private var showPicker = false
    @State private var pickerSelection = FamilyActivitySelection()
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminders") {
                    Toggle("Enabled", isOn: $model.schedule.enabled)
                    Stepper("From \(model.schedule.startHour):00",
                            value: $model.schedule.startHour, in: 0...22)
                    Stepper("Until \(model.schedule.endHour):00",
                            value: $model.schedule.endHour, in: (model.schedule.startHour + 1)...23)
                    Stepper("Every \(model.schedule.everyMinutes) min",
                            value: $model.schedule.everyMinutes, in: 15...240, step: 15)
                    Text("\(model.schedule.minutesOfDay.count) checks a day")
                        .foregroundStyle(.secondary)
                    Button("Save schedule") { model.saveSchedule() }
                }

                Section {
                    Toggle("Vibrate", isOn: $model.alerts.vibrate)
                    Toggle("Sound", isOn: $model.alerts.soundEnabled)
                    if model.alerts.soundEnabled {
                        Picker("Sound", selection: $model.alerts.sound) {
                            ForEach(AlertSettings.Sound.allCases) { Text($0.title).tag($0) }
                        }
                        Button("Play sound") { AlertPlayer.play(model.alerts.sound) }
                    }
                    if model.alerts.vibrate {
                        Button("Test vibration") { AlertPlayer.vibrate(times: 3) }
                    }
                } header: {
                    Text("Reminder alerts")
                } footer: {
                    Text("With WaterSipAI open, a reminder vibrates 3 times. When it arrives as a notification, iOS vibrates once, and only if vibration is on in your iPhone's Sounds & Haptics settings. The silent switch mutes sounds.")
                }
                .onChange(of: model.alerts) { _, _ in model.saveAlerts() }

                #if SCREEN_TIME
                Section {
                    Button("Choose always-allowed apps") {
                        pickerSelection = model.allowedApps
                        showPicker = true
                    }
                    Text("\(model.allowedApps.applicationTokens.count) apps allowed during a lock")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Always allowed")
                } footer: {
                    Text("Pick WaterSipAI itself, plus anything you must never lose, like Phone.")
                }
                #else
                Section {
                    Text("At each reminder, WaterSipAI stays on the camera check until you drink. It doesn't block other apps.")
                        .foregroundStyle(.secondary)
                }
                #endif

                if FeatureFlags.testingTools {
                    Section {
                        Button("Lock now") { model.lockNow() }
                        Toggle("Show detection details", isOn: $showDebug)
                    } header: {
                        Text("Testing")
                    } footer: {
                        Text("Detection details show what the camera check sees. You can also triple-tap the camera screen.")
                    }
                }

                LearningSection()

                Section("Privacy") {
                    PrivacyPointsView()
                        .padding(.vertical, 4)
                    Link("Privacy policy", destination: AppLinks.privacy)
                    Link("Support", destination: AppLinks.support)
                }
            }
            .navigationTitle("Settings")
            #if SCREEN_TIME
            .familyActivityPicker(isPresented: $showPicker, selection: $pickerSelection)
            .onChange(of: pickerSelection) { _, sel in model.saveAllowedApps(sel) }
            #endif
        }
    }
}
