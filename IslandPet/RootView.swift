import SwiftUI

/// Adoption when there is no pet, otherwise the home screen.
struct RootView: View {
    private var store: PetStore { .shared }

    var body: some View {
        Group {
            if store.pet == nil {
                AdoptionFlow()
            } else {
                HomeView()
            }
        }
        .animation(.snappy, value: store.pet == nil)
        .tint(Pastel.coral)
        .fontDesign(.rounded)
    }
}

#Preview {
    RootView()
}
