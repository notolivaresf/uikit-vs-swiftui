# Data flow: models, Observation and property updates

How model changes reach views. The rule: one source of truth per piece of state, one path from it to the screen, and views that read state at update time rather than caching copies.

## Where state lives

| State | Lives in |
|---|---|
| App data (messages, documents) | a model store outside view controllers: an actor, a database layer, or `@Observable` model objects on the main actor |
| Screen state (selection, filter, editing) | the view controller, or a small `@Observable` screen model it owns |
| Transient view state (highlight, pressed) | the view or cell, through configuration state |
| Values for a whole subtree (theme, density) | a custom trait (see `traits-and-environment.md`) |

- View controllers read from the store and send intents ("delete this ID") back; they do not own copies of app data that drift.
- Pass dependencies in through initializers. Avoid singletons reached from views; they hide data flow and block testing.

## Observation in UIKit

UIKit tracks reads of `@Observable` properties in its update methods and runs those methods again when the properties change. On iOS 26 and later this is on by default. On iOS 18 it needs the Info.plist key `UIObservationTrackingEnabled` set to YES.

Tracked methods include:

- `UIView`: `layoutSubviews()`, `updateConstraints()`, `draw(_:)`, `updateProperties()` (iOS 26+)
- `UIViewController`: `viewWillLayoutSubviews()`, `viewDidLayoutSubviews()`, `updateViewConstraints()`, `updateProperties()` (iOS 26+), `updateContentUnavailableConfiguration(using:)`
- cells: `updateConfiguration(using:)` and `configurationUpdateHandler`
- buttons: `updateConfiguration()` and `configurationUpdateHandler`

```swift
@Observable @MainActor
final class Inbox {
    var unreadCount = 0
    var isSyncing = false
}

final class InboxHeaderView: UIView {
    let inbox: Inbox
    private let badge = UILabel()
    private let spinner = UIActivityIndicatorView()

    override func updateProperties() {        // iOS 26+
        super.updateProperties()
        badge.text = inbox.unreadCount.formatted()
        badge.isHidden = inbox.unreadCount == 0
        inbox.isSyncing ? spinner.startAnimating() : spinner.stopAnimating()
    }
}
```

- Read the model inside the tracked method. A value copied into a stored property in `viewDidLoad` is not tracked.
- Only properties actually read in the last run are tracked. A branch that skips a read stops tracking that property until a run reads it again; that is correct behavior.
- Keep tracked methods cheap: they rerun whenever a dependency changes.
- Observation does not replace snapshots. Which items a list shows still changes through snapshot applies; content of visible cells can update through tracked configuration handlers.

Wrong: a manual observer per property plus caching.

```swift
NotificationCenter.default.addObserver(self, selector: #selector(unreadChanged), name: .unreadChanged, object: nil)
@objc func unreadChanged() { badge.text = "\(cachedUnread)" }
```

Right: read the observable model in `updateProperties()` (iOS 26+) or `layoutSubviews()`.

### Supporting iOS 18 and 26 together

- On iOS 18 with the Info.plist key, tracking works in layout and configuration methods, but `updateProperties()` does not exist. Put model reads that set properties in `layoutSubviews()` or `viewWillLayoutSubviews()` behind `if #available(iOS 26, *)` checks only where needed, or keep an explicit path (a stream or closure that calls `setNeedsLayout()`).
- Without the key on iOS 18, nothing is tracked; keep an explicit update path.

## updateProperties (iOS 26+)

`updateProperties()` on `UIView` and `UIViewController` is the place to set properties from state: text, colors, images, `isHidden`, `isEnabled`. It runs before `layoutSubviews()` in the update cycle, and separately from it, so a property change does not force a layout pass.

- Call `super.updateProperties()` (the method requires it).
- Request a run with `setNeedsUpdateProperties()` when non-observable inputs change. Observable reads schedule it for you.
- Force a pending update now with `updatePropertiesIfNeeded()`.
- Do geometry in `layoutSubviews()`, not here. Do property sets here, not in `layoutSubviews()`.

## Animating model changes (iOS 26+)

`UIView.AnimationOptions.flushUpdates` applies pending property and layout updates inside the animation, so a change to an observable model or a constraint animates without a manual `layoutIfNeeded()`:

```swift
UIView.animate(withDuration: 0.3, delay: 0, options: .flushUpdates) {
    inbox.isExpanded.toggle()     // tracked views update and animate
}
```

`UIViewPropertyAnimator` has a matching `flushUpdates` property. On earlier systems, change the state, then call `layoutIfNeeded()` on the common ancestor inside the animation block.

## Explicit update paths

When Observation is not available or not wanted:

- A model store exposes an `AsyncStream` of changes; the controller consumes it in a stored task and applies snapshots or reconfigures (see `concurrency.md`).
- A delegate or closure on the model; set it once, capture weakly.
- Key-value observing with `observe(_:options:changeHandler:)` for `NSObject` models; keep the returned token and let it go away with the observer.
- `NotificationCenter` only for app-wide, loosely coupled events (account changed, store reset), not per-property updates.

Whatever the path: coalesce bursts, and apply on the main actor from one method.

## Lists and Observation

- Identity and order: a snapshot built from the store's IDs.
- Content: either reconfigure changed IDs when the store reports them, or let tracked `configurationUpdateHandler`s read observable models directly so visible cells update themselves.
- With the second option, cells must look up their model by ID on each run; capturing the model object in the closure keeps a stale reference after the item is replaced.
- Compositional layout section providers read traits and container size; on iOS 27 they also take part in Observation tracking (see the whats-new skill).

## Review checks

1. One source of truth; views read state, they do not keep copies.
2. Observable reads happen inside tracked methods.
3. Property sets in `updateProperties()` (iOS 26+), geometry in `layoutSubviews()`.
4. iOS 18 targets either set `UIObservationTrackingEnabled` or keep an explicit path.
5. Updates funnel through one main-actor method.
