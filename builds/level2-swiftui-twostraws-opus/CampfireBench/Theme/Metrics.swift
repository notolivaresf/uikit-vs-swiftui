import SwiftUI

/// Sizes measured from Campfire (`Fixtures/constants.json`). Font sizes and line heights follow Dynamic Type;
/// paddings, radii and avatars stay fixed, as Campfire's do.
struct Metrics: Equatable, Sendable {
    /// Body point size relative to the default (Large) Dynamic Type size.
    let scale: CGFloat

    init(dynamicTypeSize: DynamicTypeSize) {
        scale = Self.bodyPoints(for: dynamicTypeSize) / 17
    }

    static let standard = Metrics(dynamicTypeSize: .large)

    /// Apple's body text style point sizes for each Dynamic Type size.
    static func bodyPoints(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: 14
        case .small: 15
        case .medium: 16
        case .large: 17
        case .xLarge: 19
        case .xxLarge: 21
        case .xxxLarge: 23
        case .accessibility1: 28
        case .accessibility2: 33
        case .accessibility3: 40
        case .accessibility4: 47
        case .accessibility5: 53
        @unknown default: 17
        }
    }

    // MARK: Type

    var bodySize: CGFloat { 16 * scale }
    var bodyLine: CGFloat { 22.4 * scale }
    var metaSize: CGFloat { 12.8 * scale }
    var metaLine: CGFloat { 19.2 * scale }
    /// The header line (name, time, options) is a little taller than its text.
    var headerHeight: CGFloat { 21.96 * scale }
    var separatorSize: CGFloat { 12.8 * scale }
    var separatorLine: CGFloat { 17.92 * scale }
    var emojiSize: CGFloat { 38.4 * scale }
    var emojiLine: CGFloat { 53.76 * scale }
    var codeSize: CGFloat { 12.8 * scale }
    var codeLine: CGFloat { 17.92 * scale }
    var boostEmojiSize: CGFloat { 17.6 * scale }
    var boostTextSize: CGFloat { 14 * scale }
    var mentionAvatarSize: CGFloat { 17 * scale }

    // MARK: Fixed geometry

    static let screenPaddingX: CGFloat = 14
    static let avatarSize: CGFloat = 35.27
    static let avatarRing: CGFloat = 2.5
    /// Bubble left edge (40.8) minus the screen padding: the avatar overlaps the bubble.
    static let bubbleOffset: CGFloat = 26.8
    static let bubbleRadius: CGFloat = 10.56
    static let bubblePaddingY: CGFloat = 10.56
    static let bubblePaddingX: CGFloat = 15.12
    static let rowTopInset: CGFloat = 1.59
    static let rowBottomInset: CGFloat = 1.6
    static let rowGap: CGFloat = 21.28
    /// Threaded rows pull up by 22.48 against the 21.28 gap.
    static let threadedGap: CGFloat = -1.2

    static let separatorMarginTop: CGFloat = 17.02
    static let separatorMarginBottom: CGFloat = 16.88
    static let separatorPadY: CGFloat = 8.5
    static let separatorPadX: CGFloat = 23.5
    static let separatorLineWidth: CGFloat = 2

    static let imageWidth: CGFloat = 300
    static let imageInset: CGFloat = 1
    static let imageTopGap: CGFloat = 11.48

    static let codeRadius: CGFloat = 6.4
    static let codePadding: CGFloat = 12.8

    static let boostHeight: CGFloat = 28.64
    static let boostAvatar: CGFloat = 24
    static let boostSpacing: CGFloat = 4.5
    static let boostTopGap: CGFloat = 4
    static let boostTopGapAfterImage: CGFloat = 5
    static let boostBottomAfterImage: CGFloat = 8

    static let fileRowHeight: CGFloat = 33.92
    static let fileButton: CGFloat = 34

    static let headerBarHeight: CGFloat = 58
    static let headerButton: CGFloat = 42
}

extension EnvironmentValues {
    @Entry var metrics = Metrics.standard
}

extension View {
    /// CSS-style line height: SwiftUI adds the extra leading between lines, so half of it also goes above the
    /// first line and below the last one.
    func lineHeight(_ lineHeight: CGFloat, fontSize: CGFloat, ratio: CGFloat = FontRatio.system) -> some View {
        let extra = max(0, lineHeight - fontSize * ratio)
        return self.lineSpacing(extra).padding(.vertical, extra / 2)
    }
}

/// Natural line height of a font as a multiple of its point size (ascent + descent + leading).
enum FontRatio {
    static let system: CGFloat = 1.1934
    static let mono: CGFloat = 1.1934
}
