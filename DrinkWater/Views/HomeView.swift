import SwiftUI
#if SCREEN_TIME
import FamilyControls
#endif

struct HomeView: View {
    @EnvironmentObject var model: AppModel
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
                    Text("Pick DrinkWater itself, plus anything you must never lose, like Phone.")
                }
                #else
                Section {
                    Text("This free build can't block other apps. It reminds you and locks DrinkWater itself until you drink.")
                        .foregroundStyle(.secondary)
                }
                #endif

                Section("Last drink") {
                    if let last = SharedStore.lastDrink {
                        Text(last, style: .relative) + Text(" ago")
                    } else {
                        Text("No drinks verified yet").foregroundStyle(.secondary)
                    }
                }

                Section("Testing") {
                    Button("Lock now") { model.lockNow() }
                }
            }
            .navigationTitle("DrinkWater")
            #if SCREEN_TIME
            .familyActivityPicker(isPresented: $showPicker, selection: $pickerSelection)
            .onChange(of: pickerSelection) { _, sel in model.saveAllowedApps(sel) }
            #endif
        }
    }
}
