import SwiftUI

/// First run: pick a species, preview coats, choose a personality, name the pet, adopt.
/// Everything else (accessories, reminders) is postponed to the home screen.
struct AdoptionFlow: View {
    @State private var species: PetSpecies = .cat
    @State private var coat: PetCoat = .honey
    @State private var personality: PetPersonality = .curious
    @State private var name = PetSpecies.cat.defaultName
    @FocusState private var nameFocused: Bool

    private var store: PetStore { .shared }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("Adopt a friend")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(Pastel.ink)
                        Text("A tiny companion that lives in your Dynamic Island.")
                            .font(.subheadline)
                            .foregroundStyle(Pastel.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    PetPreviewCard(species: species, coat: coat, accessory: .none, name: name.isEmpty ? species.defaultName : name)

                    SectionCard(title: "Companion") {
                        SpeciesPicker(selection: $species, coat: coat)
                    }
                    SectionCard(title: "Coat") {
                        CoatPicker(species: species, selection: $coat)
                    }
                    SectionCard(title: "Personality") {
                        PersonalityPicker(selection: $personality)
                    }
                    SectionCard(title: "Name") {
                        TextField("Name your pet", text: $name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($nameFocused)
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Pastel.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityLabel("Pet name")
                    }

                    PrimaryButton(title: "Adopt \(name.trimmingCharacters(in: .whitespaces).isEmpty ? species.defaultName : name)", symbol: "heart.fill") {
                        nameFocused = false
                        store.adopt(species: species, coat: coat, name: name, personality: personality)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PastelBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: species) { previous, current in
            if name == previous.defaultName { name = current.defaultName }
        }
    }
}

struct PersonalityPicker: View {
    @Binding var selection: PetPersonality

    var body: some View {
        VStack(spacing: 10) {
            Picker("Personality", selection: $selection) {
                ForEach(PetPersonality.allCases) { personality in
                    Text(personality.title).tag(personality)
                }
            }
            .pickerStyle(.segmented)
            Text(selection.blurb)
                .font(.footnote)
                .foregroundStyle(Pastel.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(selection.title): \(selection.blurb)")
        }
    }
}

#Preview {
    AdoptionFlow()
}
