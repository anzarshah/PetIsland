import ActivityKit
import SwiftUI
import WidgetKit

struct PetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetAttributes.self) { context in
            PetLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Pastel.background)
                .activitySystemActionForegroundColor(Pastel.ink)
        } dynamicIsland: { context in
            let attributes = context.attributes
            let state = context.state
            let isStale = context.isStale
            let shownState: IslandState = isStale ? .sleeping : state.islandState
            let tint = attributes.coat.palette(for: attributes.species).base.color
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Button(intent: PetActionIntent(action: .pet)) {
                        CompactPetView(species: attributes.species, coat: attributes.coat, accessory: attributes.accessory, state: shownState)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pet \(attributes.name)")
                    .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    PetCaption(name: attributes.name, caption: isStale ? PetLockScreenView.restingCaption(for: attributes.name) : state.caption, onDark: true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        IslandStatusGlyph(attributes: attributes, state: state, isStale: isStale)
                            .frame(height: 24)
                        VisitTimer(attributes: attributes, onDark: true)
                    }
                    .padding(.trailing, 2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !isStale {
                        QuickActionButton(attributes: attributes, state: state)
                            .padding(.top, 4)
                    }
                }
            } compactLeading: {
                CompactPetView(species: attributes.species, coat: attributes.coat, accessory: attributes.accessory, state: shownState)
                    .frame(width: 24, height: 24)
                    .padding(.leading, 2)
                    .accessibilityLabel(attributes.name)
            } compactTrailing: {
                IslandStatusGlyph(attributes: attributes, state: state, isStale: isStale)
                    .frame(height: 22)
                    .padding(.trailing, 2)
            } minimal: {
                CompactPetView(species: attributes.species, coat: attributes.coat, accessory: attributes.accessory, state: shownState)
                    .frame(width: 22, height: 22)
                    .accessibilityLabel(attributes.name)
            }
            .widgetURL(URL(string: "islandpet://care"))
            .keylineTint(tint)
        }
    }
}

#Preview("Dynamic Island", as: .dynamicIsland(.compact), using: PetAttributes.preview) {
    PetLiveActivity()
} contentStates: {
    PetAttributes.ContentState.preview
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: PetAttributes.preview) {
    PetLiveActivity()
} contentStates: {
    PetAttributes.ContentState.preview
}

#Preview("Lock Screen", as: .content, using: PetAttributes.preview) {
    PetLiveActivity()
} contentStates: {
    PetAttributes.ContentState.preview
}
