import SwiftUI

struct SelectionTextRenderer: TextRenderer {
    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        for line in layout { ctx.draw(line) }
    }
}
