import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import CampfireKit

@main
struct RenderChecks {
    @MainActor static func main() throws {
        let data = FakeData.generate(size: .k50)
        let users = Dictionary(uniqueKeysWithValues: data.users.map { ($0.id, $0) })
        for dark in [false, true] {
            let theme = RoomTheme(dark: dark)
            let page = Array(data.messages.suffix(40))
            let showcase = VStack(spacing: 0) {
                ForEach(page.prefix(14)) { m in
                    let previous = data.messages[m.id - 2]
                    MessageRow(message: m, presentation: Grouping.presentation(of: m, after: previous, currentUserID: 1),
                               users: users, theme: theme, scale: 1, availableWidth: 393)
                        .padding(.top, Grouping.presentation(of: m, after: data.messages[m.id - 2], currentUserID: 1).spacingBefore)
                }
            }.frame(width: 393).background(theme.background)
                .environment(\.colorScheme, dark ? .dark : .light)
            try save(showcase, name: "showcase\(dark ? "-dark" : "")")
            let bottom = VStack(spacing: 0) {
                RoomHeader(name: data.room.name, theme: theme)
                VStack(spacing: 0) {
                    ForEach(page) { m in
                        MessageRow(message: m, presentation: Grouping.presentation(of: m, after: data.messages[m.id - 2], currentUserID: 1),
                                   users: users, theme: theme, scale: 1, availableWidth: 393)
                        .padding(.top, Grouping.presentation(of: m, after: data.messages[m.id - 2], currentUserID: 1).spacingBefore)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 702, alignment: .bottom)
                .clipped()
                RoomComposer(theme: theme)
            }
            .frame(width: 393, height: 852).background(theme.background)
            .environment(\.colorScheme, dark ? .dark : .light)
            try save(bottom, name: "initial-room\(dark ? "-dark" : "")")
            let chrome = VStack(spacing: 0) {
                RoomHeader(name: "General", theme: theme)
                Spacer()
                RoomComposer(theme: theme)
            }.frame(width: 393, height: 852).background(theme.background)
            try save(chrome, name: "chrome\(dark ? "-dark" : "")")
        }
        let manyBoosts = data.messages[49973]
        let presentation = Grouping.presentation(of: manyBoosts, after: data.messages[49972], currentUserID: 1)
        var heights: [String: Int] = [:]
        for (name, width, scale) in [("boosts-default", CGFloat(393), CGFloat(1)),
                                     ("boosts-large", CGFloat(393), CGFloat(1.5)),
                                     ("boosts-wide", CGFloat(1200), CGFloat(1))] {
            let row = MessageRow(message: manyBoosts, presentation: presentation, users: users,
                                 theme: RoomTheme(dark: false), scale: scale, availableWidth: width)
                .frame(width: width).background(.white)
            try save(row, name: name)
            heights[name] = ImageRenderer(content: row).cgImage!.height
        }
        precondition(heights["boosts-large"]! > heights["boosts-default"]!, "Larger text must wrap boosts into more rows")
        precondition(heights["boosts-wide"]! < heights["boosts-default"]!, "A wider window must reflow the text and boost strip")
    }
    @MainActor static func save<V: View>(_ view: V, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.cgImage else { fatalError("No image \(name)") }
        let url = URL(fileURLWithPath: "runs/\(name).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError() }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        print(name, "\(image.width)x\(image.height)")
    }
}
