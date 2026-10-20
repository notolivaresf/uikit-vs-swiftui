#if DEBUG
import SwiftUI

/// Draws one fixture row with its top at y = 100 pt, for pixel comparison with screenshots/row-*.png.
struct FixtureRowView: View {
    @Environment(\.colorScheme) private var scheme
    let index = UserDefaults.standard.integer(forKey: "uvsRow")

    var body: some View {
        let palette = Palette.of(scheme)
        ZStack(alignment: .topLeading) {
            palette.background
            MessageRow(item: Fixture.rows[index], people: Fixture.people)
                .frame(width: 393)
                .offset(y: 100)
        }
        .ignoresSafeArea()
        .environment(\.palette, palette)
        .environment(\.listWidth, 393)
        .environment(SelectionModel())
    }
}
#endif
