import SwiftUI
import SwiftData

/// Profil & Ziele: Eingaben → Best-Practice-Rechner → Live-Vorschau des kcal-/Makro-Ziels.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile
    var embedded: Bool = false

    private let health = NutritionHealthStore()
    @State private var importMessage: String?
    @AppStorage(GeminiFoodVision.apiKeyDefaultsKey) private var geminiKey: String = ""
    @AppStorage(USDAClient.apiKeyDefaultsKey) private var usdaKey: String = ""
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var showWhatsNew = false
    @State private var reminders = RemindersSettings()
    @Environment(\.scenePhase) private var scenePhase
    @State private var healthSkinType: FitzpatrickSkinType? = nil
    @State private var healthFields: Set<String> = []
    @State private var loc = LocalizationManager.shared

    private let rateOptions: [(Double, String)] = [
        ( 0.50, "goal.gain_0_5".localized()),
        ( 0.25, "goal.gain_0_25".localized()),
        ( 0.00, "goal.maintain".localized()),
        (-0.25, "goal.lose_0_25".localized()),
        (-0.50, "goal.lose_0_5".localized()),
        (-0.75, "goal.lose_0_75".localized()),
        (-1.00, "goal.lose_1_0".localized())
    ]

    private var customSum: Double { profile.customCarbPct + profile.customProteinPct + profile.customFatPct }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { importFromHealth() } label: {
                        Label("settings.import_health".localized(), systemImage: "heart.text.square")
                    }
                    if let importMessage {
                        Text(importMessage).font(.caption).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("settings.import_health.footer".localized())
                }

                Section("settings.section.region_language".localized()) {
                    Picker("settings.region".localized(), selection: Binding(
                        get: { loc.currentRegion },
                        set: { loc.currentRegion = $0 })) {
                        ForEach(AppRegion.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("settings.language".localized(), selection: Binding(
                        get: { loc.currentLanguage },
                        set: { loc.currentLanguage = $0 })) {
                        ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                    }
                }

                Section("settings.section.bodydata".localized()) {
                    Picker("settings.gender".localized(), selection: $profile.sex) {
                        ForEach(Sex.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("\("settings.age".localized()): \(profile.age)", value: $profile.age, in: 14...100)
                    bodyNumberRow("settings.height".localized(), value: $profile.heightCm, unit: "cm", key: "height")
                    bodyNumberRow("settings.weight".localized(), value: $profile.weightKg, unit: "kg", key: "weight")
                    bodyNumberRow("settings.bodyfat".localized(), value: bodyFatBinding, unit: "%", key: "bodyfat")
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("settings.skintype".localized())
                            if healthSkinType != nil && healthSkinType == profile.skinType { healthBadge }
                        }
                        SkinTonePicker(selection: $profile.skinType)
                        Text(profile.skinType.displayName).font(.caption.bold())
                        if healthSkinType == nil, let url = URL(string: "x-apple-health://") {
                            Link(destination: url) {
                                Label("settings.skintype.health_empty".localized(), systemImage: "heart.text.square")
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section {
                    Picker("settings.activity_level".localized(), selection: $profile.activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("settings.section.activity".localized())
                } footer: {
                    Text("settings.activity.footer".localized())
                }

                Section("settings.section.goal".localized()) {
                    Picker("settings.weekly_goal".localized(), selection: $profile.weeklyRateKg) {
                        ForEach(rateOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("settings.section.macros".localized()) {
                    Picker("settings.strategy".localized(), selection: $profile.macroStrategy) {
                        ForEach(MacroStrategy.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.navigationLink)

                    if profile.macroStrategy == .custom {
                        numberRow("nutrient.carbs".localized(), value: $profile.customCarbPct, unit: "%")
                        numberRow("nutrient.protein".localized(), value: $profile.customProteinPct, unit: "%")
                        numberRow("nutrient.fat".localized(), value: $profile.customFatPct, unit: "%")
                        HStack {
                            Text("settings.sum".localized())
                            Spacer()
                            Text("\(Int(customSum)) %")
                                .foregroundStyle(abs(customSum - 100) < 0.5 ? Color.secondary : Color.red)
                        }
                    }
                }

                Section {
                    Toggle("settings.adaptive".localized(), isOn: $profile.useAdaptiveTDEE)
                } header: {
                    Text("settings.section.metabolism".localized())
                } footer: {
                    Text("settings.adaptive.footer".localized())
                }

                Section("Apple Health") {
                    Toggle("settings.exercise_cals".localized(), isOn: $profile.useExerciseCalories)
                        .disabled(profile.useAdaptiveTDEE)
                    Text(profile.useAdaptiveTDEE
                         ? "settings.exercise_cals.footer_adaptive".localized()
                         : "settings.exercise_cals.footer_normal".localized())
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("settings.section.your_goal".localized()) {
                    resultRow("nutrient.calories".localized(), "\(Int(profile.kcalTarget)) kcal", emphasized: true)
                    resultRow("nutrient.carbs".localized(), "\(Int(profile.targets.carbsG)) g")
                    resultRow("nutrient.protein".localized(), "\(Int(profile.targets.proteinG)) g")
                    resultRow("nutrient.fat".localized(), "\(Int(profile.targets.fatG)) g")
                    resultRow("\("settings.bmr".localized()) (\(profile.bmrMethod))", "\(Int(profile.bmr.rounded())) kcal")
                    resultRow("settings.tdee".localized(), "\(Int(profile.tdee.rounded())) kcal")
                    if profile.isFloored {
                        Text("\("settings.floored.prefix".localized()) \(Int(profile.kcalFloor)) \("settings.floored.suffix".localized())")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section {
                    SecureField("settings.gemini.placeholder".localized(), text: $geminiKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if !geminiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label("settings.gemini.active".localized(), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green).font(.caption)
                    }
                    if let u = URL(string: "https://aistudio.google.com/app/apikey") {
                        Link(destination: u) {
                            Label("settings.gemini.create".localized(), systemImage: "safari").font(.caption)
                        }
                    }
                } header: {
                    Text("settings.section.gemini".localized())
                } footer: {
                    Text("settings.gemini.footer".localized())
                }

                Section {
                    SecureField("settings.usda.placeholder".localized(), text: $usdaKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if usdaKey.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label("settings.usda.demo".localized(), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).font(.caption)
                    } else {
                        Label("settings.usda.active".localized(), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green).font(.caption)
                    }
                    if let u = URL(string: "https://fdc.nal.usda.gov/api-key-signup") {
                        Link(destination: u) {
                            Label("settings.usda.create".localized(), systemImage: "safari").font(.caption)
                        }
                    }
                } header: {
                    Text("settings.section.usda".localized())
                } footer: {
                    Text("settings.usda.footer".localized())
                }

                Section {
                    DisclosureGroup("settings.apihelp.title".localized()) {
                        VStack(alignment: .leading, spacing: 10) {
                            keyGuide(
                                title: "Gemini-Key (Gericht-Foto-KI)",
                                urlString: "https://aistudio.google.com/app/apikey",
                                steps: ["Unten auf den Link zum Öffnen der Seite tippen",
                                        "Mit Google-Konto anmelden",
                                        "„Create API key“ / „API-Key erstellen“",
                                        "Key kopieren und oben bei „KI-Bilderkennung“ einfügen"])
                            Divider()
                            keyGuide(
                                title: "USDA-Key (Nährwert-Datenbank)",
                                urlString: "https://fdc.nal.usda.gov/api-key-signup",
                                steps: ["Unten auf den Link zum Öffnen der Seite tippen",
                                        "Name + E-Mail eingeben, absenden",
                                        "Key kommt sofort per E-Mail",
                                        "Key kopieren und oben bei „Nährwert-Datenbank“ einfügen"])
                            Text("settings.keys_free_note".localized())
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("settings.section.appearance".localized()) {
                    Picker("settings.appearance_mode".localized(), selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("settings.section.reminders".localized()) {
                    NavigationLink {
                        RemindersSettingsView { reminders = $0 }
                    } label: {
                        Label("settings.configure_reminders".localized(), systemImage: "bell.badge")
                    }
                }

                Section {
                    Button {
                        showWhatsNew = true
                    } label: {
                        Label("settings.whatsnew".localized(), systemImage: "sparkles")
                    }
                    HStack {
                        Text("settings.version".localized())
                        Spacer()
                        Text(Theme.appVersion).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("settings.section.about".localized())
                }

                Section {
                    Text("settings.estimates_disclaimer".localized())
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(embedded ? "settings.title".localized() : "goals.title".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { try? context.save(); dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
            .task { loadSkinTypeFromHealth() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { loadSkinTypeFromHealth() }
            }
        }
    }

    private var bodyFatBinding: Binding<Double> {
        Binding(
            get: { profile.bodyFatPercent ?? 0 },
            set: { profile.bodyFatPercent = $0 > 0 ? $0 : nil }
        )
    }

    private func importFromHealth() {
        Task { @MainActor in
            try? await health.requestAuthorization()
            let d = await health.readBodyData()
            var fields: Set<String> = []
            if let s = d.sex { profile.sex = s; fields.insert("sex") }
            if let a = d.age { profile.age = a; fields.insert("age") }
            if let h = d.heightCm { profile.heightCm = (h * 10).rounded() / 10; fields.insert("height") }
            if let w = d.weightKg { profile.weightKg = (w * 10).rounded() / 10; fields.insert("weight") }
            if let bf = d.bodyFatPercent { profile.bodyFatPercent = (bf * 10).rounded() / 10; fields.insert("bodyfat") }
            if let st = await health.readFitzpatrickSkinType() { profile.skinType = st; healthSkinType = st }
            healthFields = fields
            try? context.save()
            importMessage = d.hasAny ? "Werte aus Apple Health übernommen."
                                     : "Keine Körperdaten in Apple Health gefunden."
        }
    }

    private func loadSkinTypeFromHealth() {
        Task { @MainActor in
            let t = await health.readFitzpatrickSkinType()
            if let t {
                healthSkinType = t
                if profile.skinType != t { profile.skinType = t; try? context.save() }
            } else {
                healthSkinType = nil
            }
        }
    }

    private var healthBadge: some View {
        Text("Apple Health")
            .font(.caption2)
            .foregroundStyle(.pink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.pink.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func bodyNumberRow(_ label: String, value: Binding<Double>, unit: String, key: String) -> some View {
        HStack {
            Text(label)
            if healthFields.contains(key) { healthBadge }
            Spacer()
            TextField(unit, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func keyGuide(title: String, urlString: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(i + 1).").font(.caption).foregroundStyle(.secondary)
                    Text(step).font(.caption)
                }
            }
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    Label(String(format: "settings.open_page".localized(), urlString.replacingOccurrences(of: "https://", with: "")),
                          systemImage: "safari")
                        .font(.caption)
                }
                .padding(.top, 2)
            }
        }
    }

    private func numberRow(_ label: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(unit, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func resultRow(_ label: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label).font(emphasized ? .body.bold() : .body)
            Spacer()
            Text(value)
                .font(emphasized ? .body.bold() : .body)
                .foregroundStyle(emphasized ? .primary : .secondary)
                .monospacedDigit()
        }
    }
}
