import SwiftUI

/// Cosmetic edits that keep the pet's age, needs and bond, plus the explicit way to say goodbye.
struct EditPetSheet: View {
    var pet: PetState

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var coat: PetCoat
    @State private var accessory: PetAccessory
    @State private var personality: PetPersonality
    @State private var confirmGoodbye = false

    private var store: PetStore { .shared }

    init(pet: PetState) {
        self.pet = pet
        _name = State(initialValue: pet.name)
        _coat = State(initialValue: pet.coat)
        _accessory = State(initialValue: pet.accessory)
        _personality = State(initialValue: pet.personality)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PetPreviewCard(species: pet.species, coat: coat, accessory: accessory, name: name.trimmingCharacters(in: .whitespaces).isEmpty ? pet.species.defaultName : name)
                    SectionCard(title: "Name") {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Pastel.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityLabel("Pet name")
                    }
                    SectionCard(title: "Coat") {
                        CoatPicker(species: pet.species, selection: $coat)
                    }
                    SectionCard(title: "Accessory") {
                        AccessoryPicker(selection: $accessory)
                    }
                    SectionCard(title: "Personality") {
                        PersonalityPicker(selection: $personality)
                    }
                    SectionCard(title: "Say goodbye") {
                        Text("Adopting a new companion means parting with \(pet.displayName). This can't be undone.")
                            .font(.footnote)
                            .foregroundStyle(Pastel.muted)
                        Button("Say goodbye to \(pet.displayName)…", role: .destructive) {
                            confirmGoodbye = true
                        }
                        .font(.subheadline.weight(.bold))
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PastelBackground())
            .navigationTitle("Edit \(pet.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.edit(name: name, coat: coat, accessory: accessory, personality: personality)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .confirmationDialog("Say goodbye to \(pet.displayName)?", isPresented: $confirmGoodbye, titleVisibility: .visible) {
                Button("Say goodbye", role: .destructive) {
                    Task {
                        await IslandVisitManager.shared.endVisit()
                        store.release()
                        dismiss()
                    }
                }
                Button("Keep \(pet.displayName)", role: .cancel) {}
            } message: {
                Text("\(pet.displayName)'s age, bond and memories go with them. You can adopt a new friend afterwards.")
            }
        }
    }
}
