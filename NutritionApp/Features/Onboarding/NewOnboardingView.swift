import SwiftUI
import SwiftData
import HealthKit

struct NewOnboardingView: View {
    @Environment(\.modelContext) var modelContext
    let onDone: () -> Void

    private let healthStore = NutritionHealthStore()

    @State private var currentStep = 0
    @State private var selectedRegion: AppRegion = .usa
    @State private var selectedLanguage: AppLanguage = .english
    @State private var selectedFormat: UnitSystem = .metric
    @State private var selectedGender: Gender = .male
    @State private var height: String = "180"
    @State private var age: String = "30"
    @State private var selectedSkinType: FitzpatrickSkinType = .typeII
    @State private var isLoadingHealthData = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                // Screen 1: Region & Language
                screen1RegionLanguage.tag(0)

                // Screen 2: Format & Personal Data
                screen2PersonalData.tag(1)

                // Screen 3: Confirmation
                screen3Confirmation.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Navigation buttons
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                }

                Button(currentStep < 2 ? "Continue" : "Start") {
                    if currentStep < 2 {
                        withAnimation { currentStep += 1 }
                    } else {
                        completeOnboarding()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
                .fontWeight(.semibold)
            }
            .padding(20)
        }
        .task {
            await loadHealthKitData()
        }
    }

    private func loadHealthKitData() async {
        isLoadingHealthData = true
        // Request authorization first, THEN read. Otherwise a brand new user sees the
        // defaults (Male/180/30) because the read fires before the permission dialog is
        // answered on the very first launch (Bug 2: first-launch HealthKit race).
        try? await healthStore.requestAuthorization()
        let bodyData = await healthStore.readBodyData()

        if let age = bodyData.age {
            self.age = String(age)
        }
        if let height = bodyData.heightCm {
            self.height = String(Int(height))
        }
        if let sex = bodyData.sex {
            self.selectedGender = (sex == .male) ? .male : .female
        }
        if let skin = await healthStore.readFitzpatrickSkinType() {
            self.selectedSkinType = skin
        }

        isLoadingHealthData = false
    }

    // MARK: - Screens

    private var screen1RegionLanguage: some View {
        VStack(spacing: 24) {
            Text("onboarding.region.title".localized())
                .font(.title2.weight(.bold))

            Picker("Region", selection: $selectedRegion) {
                ForEach(AppRegion.allCases) { region in
                    Text("\(flagForRegion(region)) \(region.displayName)").tag(region)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)

            Text("onboarding.language.title".localized())
                .font(.title2.weight(.bold))
                .padding(.top, 20)

            Picker("Language", selection: $selectedLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text("\(flagForLanguage(lang)) \(lang.displayName)").tag(lang)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)

            Spacer()
        }
        .padding(20)
    }

    private func flagForRegion(_ region: AppRegion) -> String {
        switch region {
        case .germany: return "🇩🇪"
        case .austria: return "🇦🇹"
        case .switzerlandDE, .switzerlandFR, .switzerlandIT: return "🇨🇭"
        case .france: return "🇫🇷"
        case .usa: return "🇺🇸"
        case .canada: return "🇨🇦"
        case .uk: return "🇬🇧"
        case .australia: return "🇦🇺"
        case .india: return "🇮🇳"
        case .farsi: return "🇮🇷"
        case .arabic: return "🇸🇦"
        case .japan: return "🇯🇵"
        case .china: return "🇨🇳"
        case .serbia: return "🇷🇸"
        case .croatia: return "🇭🇷"
        case .russia: return "🇷🇺"
        case .hungary: return "🇭🇺"
        case .italy: return "🇮🇹"
        case .spain: return "🇪🇸"
        case .portugal: return "🇵🇹"
        case .brazil: return "🇧🇷"
        }
    }

    private func flagForLanguage(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .frenchSwiss: return "🇨🇭"
        case .frenchCanadian: return "🇨🇦"
        case .afrikaans: return "🇿🇦"
        case .hindi: return "🇮🇳"
        case .farsi: return "🇮🇷"
        case .arabic: return "🇸🇦"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .serbian: return "🇷🇸"
        case .serbianLatin: return "🇷🇸"
        case .croatian: return "🇭🇷"
        case .russian: return "🇷🇺"
        case .hungarian: return "🇭🇺"
        case .italian: return "🇮🇹"
        case .spanish: return "🇪🇸"
        case .portuguese: return "🇵🇹"
        case .brazilianPortuguese: return "🇧🇷"
        case .korean: return "🇰🇷"
        case .polish: return "🇵🇱"
        case .norwegian: return "🇳🇴"
        case .finnish: return "🇫🇮"
        case .swedish: return "🇸🇪"
        case .danish: return "🇩🇰"
        case .czech: return "🇨🇿"
        case .slovak: return "🇸🇰"
        case .romanian: return "🇷🇴"
        case .bulgarian: return "🇧🇬"
        case .turkish: return "🇹🇷"
        case .greek: return "🇬🇷"
        case .swahili: return "🇹🇿"
        case .oshiwambo: return "🇳🇦"
        case .khoekhoe: return "🇳🇦"
        case .herero: return "🇳🇦"
        case .silozi: return "🇳🇦"
        }
    }

    private var screen2PersonalData: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("onboarding.format.title".localized())
                    .font(.title2.weight(.bold))

                Picker("Format", selection: $selectedFormat) {
                    ForEach(UnitSystem.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Divider().padding(.vertical, 8)

                Text("onboarding.personal.title".localized())
                    .font(.title2.weight(.bold))

                VStack(spacing: 16) {
                    HStack {
                        Text("onboarding.gender".localized()).fontWeight(.semibold)
                        Spacer()
                        Picker("Gender", selection: $selectedGender) {
                            ForEach(Gender.allCases) { g in
                                Text(g.displayName).tag(g)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Text("onboarding.height".localized()).fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 8) {
                            TextField("cm", text: $height)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                            Text(selectedFormat == .metric ? "cm" : "in")
                                .font(.caption)
                        }
                    }

                    HStack {
                        Text("onboarding.age".localized()).fontWeight(.semibold)
                        Spacer()
                        TextField("years", text: $age)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(alignment: .top) {
                        Text("onboarding.skin_type".localized()).fontWeight(.semibold)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            SkinTonePicker(selection: $selectedSkinType)
                            Text(selectedSkinType.displayName)
                                .font(.caption.bold())
                            Text(selectedSkinType.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding(20)
        }
    }

    private var screen3Confirmation: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("onboarding.confirmation.title".localized())
                .font(.title.weight(.bold))

            Text("onboarding.confirmation.subtitle".localized())
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                confirmationRow("Region", selectedRegion.displayName)
                confirmationRow("Language", selectedLanguage.displayName)
                confirmationRow("Units", selectedFormat.displayName)
                confirmationRow("Gender", selectedGender.displayName)
                confirmationRow("Height", "\(height) \(selectedFormat == .metric ? "cm" : "in")")
                confirmationRow("Age", "\(age) years")
                confirmationRow("Skin Type", selectedSkinType.displayName)
            }
            .padding(16)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

            Spacer()
        }
        .padding(20)
    }

    private func confirmationRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).fontWeight(.semibold)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    // MARK: - Completion

    private func completeOnboarding() {
        // Save to UserDefaults or persistent storage
        LocalizationManager.shared.currentLanguage = selectedLanguage
        LocalizationManager.shared.currentRegion = selectedRegion
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")

        // Create/update UserProfile if needed
        let profile = UserProfile(
            sex: selectedGender == .male ? .male : .female,
            age: Int(age) ?? 30,
            heightCm: Double(height) ?? 180,
            weightKg: 75, // Will be set via weight entry
            activity: .moderate,
            weeklyRateKg: 0,
            macroStrategy: .balanced
        )
        // Persist profile...

        onDone()
    }
}

#Preview {
    NewOnboardingView(onDone: {})
}
