import SwiftUI
import SwiftData

struct NewOnboardingView: View {
    @Environment(\.modelContext) var modelContext
    let onDone: () -> Void

    @State private var currentStep = 0
    @State private var selectedRegion: AppRegion = .germany
    @State private var selectedLanguage: AppLanguage = .german
    @State private var selectedFormat: UnitSystem = .metric
    @State private var selectedGender: Gender = .male
    @State private var height: String = "180"
    @State private var age: String = "30"
    @State private var selectedSkinType: FitzpatrickSkinType = .typeII

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
    }

    // MARK: - Screens

    private var screen1RegionLanguage: some View {
        VStack(spacing: 24) {
            Text("onboarding.region.title".localized())
                .font(.title2.weight(.bold))

            Picker("Region", selection: $selectedRegion) {
                ForEach(AppRegion.allCases) { region in
                    Text(region.displayName).tag(region)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)

            Text("onboarding.language.title".localized())
                .font(.title2.weight(.bold))
                .padding(.top, 20)

            Picker("Language", selection: $selectedLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 200)

            Spacer()
        }
        .padding(20)
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
                            Picker("Skin Type", selection: $selectedSkinType) {
                                ForEach(FitzpatrickSkinType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
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
