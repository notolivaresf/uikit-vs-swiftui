import SwiftUI
import QuartzCore

@main
struct CampfireApp: App {
    /// Taken on the first line of the app's own code; the launch time in the debug bar counts from here.
    private let launchStart = CACurrentMediaTime()
    @State private var store: ChatStore
    @State private var engine: ScrollEngine
    @State private var selection = SelectionModel()
    private let showDebugBar = UserDefaults.standard.bool(forKey: "uvsBenchmark")

    /// Height of a standard window title bar on this macOS.
    static let titleBar: CGFloat = 32

    init() {
        // Each launch opens fresh: no restored window frame or state.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        let store = ChatStore()
        _store = State(initialValue: store)
        _engine = State(initialValue: ScrollEngine(store: store))
    }

    var body: some Scene {
        Window(store.roomName, id: "room") {
            RoomView(store: store, engine: engine, showDebugBar: showDebugBar, launchStart: launchStart)
                .environment(selection)
                .onAppear { selection.store = store }
                .frame(minWidth: 393, idealWidth: 393, maxWidth: .infinity,
                       minHeight: 600 + Self.titleBar, idealHeight: 852 + Self.titleBar, maxHeight: .infinity)
        }
        // The window's root view reaches under the title bar, so its sizes include it; the content area
        // below the title bar is 393 x 852.
        .defaultSize(width: 393, height: 852 + Self.titleBar)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .pasteboard) {
                Button("Copy") { selection.copy() }
                    .keyboardShortcut("c")
                    .disabled(!selection.hasSelection)
                Button("Select All") { selection.selectAll() }
                    .keyboardShortcut("a")
            }
        }
    }
}
