import SwiftUI
import MessageUI

struct NewSettingsView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var showRemindersSheet = false
    @State private var showRecommendSheet = false
    @State private var reminders = RemindersSettings()

    var body: some View {
        NavigationStack {
            Form {
                Section("Region & Language") {
                    Picker("Region", selection: Binding(
                        get: { LocalizationManager.shared.currentRegion },
                        set: { LocalizationManager.shared.currentRegion = $0 }
                    )) {
                        ForEach(AppRegion.allCases) { region in
                            Text(region.displayName).tag(region)
                        }
                    }

                    Picker("Language", selection: Binding(
                        get: { LocalizationManager.shared.currentLanguage },
                        set: { LocalizationManager.shared.currentLanguage = $0 }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }

                Section("Units") {
                    Picker("System", selection: Binding(
                        get: { LocalizationManager.shared.currentRegion },
                        set: { LocalizationManager.shared.currentRegion = $0 }
                    )) {
                        Text("Metric (ml, kg, cm)").tag(AppRegion.germany)
                        Text("Imperial (oz, lbs, in)").tag(AppRegion.usa)
                    }
                }

                Section("Personal Info") {
                    NavigationLink(destination: PersonalInfoEditView()) {
                        HStack {
                            Text("Height, Age, Gender, Skin Type")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Notifications & Reminders") {
                    NavigationLink(destination: RemindersSettingsView { newSettings in
                        reminders = newSettings
                    }) {
                        HStack {
                            Text("Configure reminders")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                }

                Section("App") {
                    Button(action: { showRecommendSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Recommend App")
                            Spacer()
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showRecommendSheet) {
                RecommendAppSheet()
            }
        }
    }
}

struct PersonalInfoEditView: View {
    @State private var height = "180"
    @State private var age = "30"
    @State private var gender: Gender = .male
    @State private var skinType: FitzpatrickSkinType = .typeII

    var body: some View {
        Form {
            Section("Physical Info") {
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("cm", text: $height)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Age")
                    Spacer()
                    TextField("years", text: $age)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }

                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases) { g in
                        Text(g.displayName).tag(g)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Skin Type")
                    SkinTonePicker(selection: $skinType)
                    Text(skinType.displayName).font(.caption.bold())
                }

                Text(skinType.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Personal Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecommendAppSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "star.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("Love NutritionApp?")
                        .font(.title2.weight(.bold))
                    Text("Share it with a friend!")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    ShareLink(item: URL(string: "https://apps.apple.com/app/nutritionapp")!, label: {
                        Label("Share via...", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    })

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Recommend")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NewSettingsView()
}
