import SwiftUI

struct RemindersSettingsView: View {
    @State private var settings = RemindersSettings()
    let onSave: (RemindersSettings) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Morning") {
                    Toggle("Enable", isOn: $settings.morningMotivationEnabled)
                    if settings.morningMotivationEnabled {
                        DatePicker("Time", selection: $settings.morningMotivationTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Meals") {
                    Toggle("Breakfast (9 AM)", isOn: $settings.breakfastReminderEnabled)
                    if settings.breakfastReminderEnabled {
                        DatePicker("Time", selection: $settings.breakfastReminderTime, displayedComponents: .hourAndMinute)
                    }

                    Toggle("Lunch (1 PM)", isOn: $settings.lunchReminderEnabled)
                    if settings.lunchReminderEnabled {
                        DatePicker("Time", selection: $settings.lunchReminderTime, displayedComponents: .hourAndMinute)
                    }

                    Toggle("Dinner (7 PM)", isOn: $settings.dinnerReminderEnabled)
                    if settings.dinnerReminderEnabled {
                        DatePicker("Time", selection: $settings.dinnerReminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Sleep") {
                    Toggle("Bedtime reminder", isOn: $settings.bedtimeReminderEnabled)
                    if settings.bedtimeReminderEnabled {
                        DatePicker("Bedtime", selection: $settings.bedtimeReminderTime, displayedComponents: .hourAndMinute)

                        Picker("Remind before", selection: $settings.bedtimeBefore) {
                            Text("30 min").tag(30)
                            Text("60 min").tag(60)
                            Text("90 min").tag(90)
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        RemindersManager.shared.scheduleReminders(settings: settings)
                        onSave(settings)
                    }
                }
            }
        }
    }
}

#Preview {
    RemindersSettingsView(onSave: { _ in })
}
