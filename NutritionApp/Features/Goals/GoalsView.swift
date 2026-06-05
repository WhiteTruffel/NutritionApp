import SwiftUI
import SwiftData

/// Profil & Ziele: Eingaben → Best-Practice-Rechner → Live-Vorschau des kcal-/Makro-Ziels.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var profile: UserProfile

    private let health = NutritionHealthStore()
    @State private var importMessage: String?
    @AppStorage(GeminiFoodVision.apiKeyDefaultsKey) private var geminiKey: String = ""
    @AppStorage(USDAClient.apiKeyDefaultsKey) private var usdaKey: String = ""
    @State private var showWhatsNew = false

    private let rateOptions: [(Double, String)] = [
        ( 0.50, "0,5 kg/Woche zunehmen"),
        ( 0.25, "0,25 kg/Woche zunehmen"),
        ( 0.00, "Gewicht halten"),
        (-0.25, "0,25 kg/Woche abnehmen"),
        (-0.50, "0,5 kg/Woche abnehmen"),
        (-0.75, "0,75 kg/Woche abnehmen"),
        (-1.00, "1 kg/Woche abnehmen")
    ]

    private var customSum: Double { profile.customCarbPct + profile.customProteinPct + profile.customFatPct }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { importFromHealth() } label: {
                        Label("Aus Apple Health übernehmen", systemImage: "heart.text.square")
                    }
                    if let importMessage {
                        Text(importMessage).font(.caption).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Liest Geschlecht, Alter, Größe, Gewicht und Körperfett (falls vorhanden).")
                }

                Section("Körperdaten") {
                    Picker("Geschlecht", selection: $profile.sex) {
                        ForEach(Sex.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Alter: \(profile.age)", value: $profile.age, in: 14...100)
                    numberRow("Größe", value: $profile.heightCm, unit: "cm")
                    numberRow("Gewicht", value: $profile.weightKg, unit: "kg")
                    numberRow("Körperfett", value: bodyFatBinding, unit: "%")
                }

                Section {
                    Picker("Aktivitätslevel", selection: $profile.activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Aktivität")
                } footer: {
                    Text("Wähle deine Grundaktivität OHNE Training. Dein Sport wird separat aus Apple Health ergänzt – so wird nichts doppelt gezählt.")
                }

                Section("Ziel") {
                    Picker("Wochenziel", selection: $profile.weeklyRateKg) {
                        ForEach(rateOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Makronährstoffe") {
                    Picker("Strategie", selection: $profile.macroStrategy) {
                        ForEach(MacroStrategy.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.navigationLink)

                    if profile.macroStrategy == .custom {
                        numberRow("Kohlenhydrate", value: $profile.customCarbPct, unit: "%")
                        numberRow("Eiweiß", value: $profile.customProteinPct, unit: "%")
                        numberRow("Fett", value: $profile.customFatPct, unit: "%")
                        HStack {
                            Text("Summe")
                            Spacer()
                            Text("\(Int(customSum)) %")
                                .foregroundStyle(abs(customSum - 100) < 0.5 ? Color.secondary : Color.red)
                        }
                    }
                }

                Section {
                    Toggle("Adaptiver Stoffwechsel (empfohlen)", isOn: $profile.useAdaptiveTDEE)
                } header: {
                    Text("Stoffwechsel")
                } footer: {
                    Text("Goldstandard wie bei MacroFactor: Die App lernt deinen echten Umsatz aus Gewichtsverlauf + tatsächlicher Zufuhr und passt das Ziel laufend an – statt Sport-Kalorien zu addieren (die Tracker oft überschätzen). Braucht ~2 Wochen durchgehendes Logging + regelmäßige Gewichtseinträge. Der gelernte Wert erscheint dann auf „Heute“. Solange zu wenig Daten da sind, gilt das berechnete Ziel unten.")
                }

                Section("Apple Health") {
                    Toggle("Sport-Kalorien dazurechnen", isOn: $profile.useExerciseCalories)
                        .disabled(profile.useAdaptiveTDEE)
                    Text(profile.useAdaptiveTDEE
                         ? "Im adaptiven Modus deaktiviert – dein Training ist über den Gewichtstrend bereits eingerechnet (kein Doppelzählen)."
                         : "Dein Aktivitätslevel zählt nur die Grundaktivität – das Training kommt hierüber. Verbleibend = Ziel − Nahrung + aktive Kalorien aus Apple Health.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Dein Ziel") {
                    resultRow("Kalorien", "\(Int(profile.kcalTarget)) kcal", emphasized: true)
                    resultRow("Kohlenhydrate", "\(Int(profile.targets.carbsG)) g")
                    resultRow("Eiweiß", "\(Int(profile.targets.proteinG)) g")
                    resultRow("Fett", "\(Int(profile.targets.fatG)) g")
                    resultRow("Grundumsatz (\(profile.bmrMethod))", "\(Int(profile.bmr.rounded())) kcal")
                    resultRow("Gesamtumsatz (TDEE)", "\(Int(profile.tdee.rounded())) kcal")
                    if profile.isFloored {
                        Text("Hinweis: Dein Wunschdefizit liegt unter der Sicherheits-Untergrenze von \(Int(profile.kcalFloor)) kcal — das Ziel wurde dort gekappt.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Section {
                    SecureField("Gemini API-Key einfügen", text: $geminiKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if !geminiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label("KI-Erkennung aktiv", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green).font(.caption)
                    }
                } header: {
                    Text("KI-Bilderkennung (Gericht-Foto)")
                } footer: {
                    Text("Optional. Mit einem kostenlosen Google-Gemini-Key erkennt „Gericht fotografieren“ echte Gerichte und schätzt Nährwerte. Ohne Key wird die einfache On-Device-Erkennung genutzt. Der Key bleibt lokal auf dem Gerät; das Foto wird zur Analyse an Google gesendet.")
                }

                Section {
                    SecureField("USDA API-Key einfügen", text: $usdaKey)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    if usdaKey.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label("Es wird DEMO_KEY genutzt (stark limitiert)", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).font(.caption)
                    } else {
                        Label("Eigener USDA-Key aktiv", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green).font(.caption)
                    }
                } header: {
                    Text("Nährwert-Datenbank (USDA)")
                } footer: {
                    Text("Optional, aber empfohlen für vollständige Vitamin-/Mineralstoff-Daten. Kostenloser Key → ~1.000 Abfragen/Std. statt 30 mit dem Standard-DEMO_KEY. Bleibt lokal auf dem Gerät.")
                }

                Section {
                    DisclosureGroup("Anleitung: API-Schlüssel holen (kostenlos)") {
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
                            Text("Beide Schlüssel sind kostenlos, ohne Kreditkarte. Sie werden nur lokal auf diesem Gerät gespeichert.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        showWhatsNew = true
                    } label: {
                        Label("Neu in dieser Version", systemImage: "sparkles")
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Theme.appVersion).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Über die App")
                }

                Section {
                    Text("Schätzwerte nach etablierten Formeln, keine medizinische Beratung. Bei Erkrankungen, Schwangerschaft o. Ä. bitte fachlichen Rat einholen.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ziele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { try? context.save(); dismiss() }
                }
            }
            .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
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
            if let s = d.sex { profile.sex = s }
            if let a = d.age { profile.age = a }
            if let h = d.heightCm { profile.heightCm = (h * 10).rounded() / 10 }
            if let w = d.weightKg { profile.weightKg = (w * 10).rounded() / 10 }
            if let bf = d.bodyFatPercent { profile.bodyFatPercent = (bf * 10).rounded() / 10 }
            try? context.save()
            importMessage = d.hasAny ? "Werte aus Apple Health übernommen."
                                     : "Keine Körperdaten in Apple Health gefunden."
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
                    Label("Seite öffnen: \(urlString.replacingOccurrences(of: "https://", with: ""))",
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
