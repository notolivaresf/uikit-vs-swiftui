import SwiftUI

@main
struct CampfireApp: App {
    @State private var model: RoomModel

    init() {
        Launch.markStart()
        _model = State(initialValue: RoomModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: RoomModel
    @Environment(\.dynamicTypeSize) private var systemTypeSize

    private static let benchmark = UserDefaults.standard.bool(forKey: "uvsBenchmark")

    private static let referenceRow = UserDefaults.standard.string(forKey: "uvsReferenceRow")

    var body: some View {
        if let name = Self.referenceRow {
            ReferenceGallery(name: name)
        } else {
            room
        }
    }

    private var room: some View {
        RoomView(model: model, showsDebugBar: Self.benchmark)
            .dynamicTypeSize(model.typeSizeOverride ?? systemTypeSize)
            .task { await model.load() }
            .onChange(of: systemTypeSize, initial: true) { _, size in model.systemTypeSize = size }
    }
}
