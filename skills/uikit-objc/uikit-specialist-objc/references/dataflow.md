# Data flow: models, update methods and property updates

How model changes reach views. The rule: one source of truth per piece of state, one path from it to the screen, and views that read state at update time rather than caching copies.

## Where state lives

| State | Lives in |
|---|---|
| App data (messages, documents) | a model store outside view controllers: a database layer or a store object with its own queue, handing out immutable values |
| Screen state (selection, filter, editing) | the view controller, or a small screen-model object it owns |
| Transient view state (highlight, pressed) | the view or cell, through configuration state |
| Values for a whole subtree (theme, density) | a custom trait (see `traits-and-environment.md`) |

- View controllers read from the store and send intents ("delete this ID") back; they do not own copies of app data that drift.
- Pass dependencies in through initializers (`-initWithStore:`). Avoid singletons reached from views; they hide data flow and block testing.
- Expose model values as `readonly` properties of immutable objects, so a change is always a new value delivered through one path.

## Observation tracking: what applies in Objective-C

Observation tracking (reading an `@Observable` property inside a UIKit update method and having UIKit rerun the method when it changes) is built on the Swift Observation framework and the `@Observable` macro. It tracks reads of Swift `@Observable` properties. An Objective-C property, a KVO-compliant property or an `NSObject` model is not tracked: reading it inside `updateProperties` or `layoutSubviews` registers nothing, and nothing reruns when it changes. The headers expose no Objective-C way to opt a property in. Do not write code that assumes it.

What does apply from Objective-C:

- **Trait tracking.** UIKit tracks reads of `self.traitCollection` (and traits read from the layout environment) inside its update methods and reruns them when the trait changes. This lives in UIKit's update cycle, so it works whatever language reads the trait. See `traits-and-environment.md`.
- **The update methods themselves.** `-updateProperties` (iOS 26+), `-setNeedsUpdateProperties` and `-updatePropertiesIfNeeded` are ordinary Objective-C methods on `UIView` and `UIViewController`. You call `-setNeedsUpdateProperties` yourself when your own state changes.
- **Cells and buttons**: `-updateConfigurationUsingState:` / `configurationUpdateHandler`, with `-setNeedsUpdateConfiguration` when your own state changes.
- **Swift models.** If part of the app is Swift and its models are `@Observable`, tracking works for reads made in Swift code inside those update methods. An Objective-C view controller that needs it can call into a small Swift view-model helper from `updateProperties` only if the Swift code does the read inside that call; keep this to a minimum and say so in the code.

So in Objective-C the model-to-view path is explicit, and short:

```objc
@implementation InboxHeaderView

- (void)setInbox:(Inbox *)inbox {
    if (_inbox == inbox) { return; }
    [_inbox removeObserver:self forKeyPath:@"unreadCount" context:InboxContext];
    _inbox = inbox;
    [_inbox addObserver:self forKeyPath:@"unreadCount" options:NSKeyValueObservingOptionNew context:InboxContext];
    [self setNeedsUpdateProperties];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (context == InboxContext) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self setNeedsUpdateProperties]; });
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateProperties {                     // iOS 26+
    [super updateProperties];                  // required
    self.badge.text = [NSString localizedStringWithFormat:@"%ld", (long)self.inbox.unreadCount];
    self.badge.hidden = self.inbox.unreadCount == 0;
}

- (void)dealloc {
    [_inbox removeObserver:self forKeyPath:@"unreadCount" context:InboxContext];
}
@end
```

- The observer is registered and removed in matching places; an unbalanced KVO observer crashes when the observed object deallocates.
- Keep the observation in one place (here, the setter) and the property writes in `-updateProperties`. Do not set labels from the KVO callback.
- Prefer a delegate, a callback block or a notification when the model is not already KVO-compliant. Adding KVO to a model only for this is more code than a delegate method.

Wrong: caching the value and mutating the label in several places.

```objc
- (void)unreadChanged:(NSNotification *)note {
    self.badge.text = [NSString stringWithFormat:@"%ld", (long)self.cachedUnread];
}
```

Right: one method that reads the model and sets all dependent properties, called for every cause.

## -updateProperties (iOS 26+)

`-updateProperties` on `UIView` and `UIViewController` is the place to set properties from state: text, colors, images, `hidden`, `enabled`. It runs before `layoutSubviews` in the update cycle, and separately from it, so a property change does not force a layout pass.

- Call `[super updateProperties]` (the method is declared `NS_REQUIRES_SUPER`).
- Request a run with `-setNeedsUpdateProperties` when your own inputs change. Requests are coalesced.
- Force a pending update now with `-updatePropertiesIfNeeded`.
- Do geometry in `layoutSubviews`, not here. Do property sets here, not in `layoutSubviews`.
- Below iOS 26 the method does not exist: guard the call with `if (@available(iOS 26.0, *)) { [view setNeedsUpdateProperties]; }` and keep a fallback path (set the properties directly, or in `layoutSubviews`).

## Animating model changes (iOS 26+)

`UIViewAnimationOptionFlushUpdates` applies pending property and layout updates inside the animation, so a change that calls `-setNeedsUpdateProperties` or changes a constraint animates without a manual `layoutIfNeeded`:

```objc
[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionFlushUpdates animations:^{
    self.inbox.expanded = !self.inbox.expanded;
    [self.header setNeedsUpdateProperties];
} completion:nil];
```

`UIViewPropertyAnimator` has a matching `flushUpdates` property. On earlier systems, change the state, then call `layoutIfNeeded` on the common ancestor inside the animation block.

## Explicit update paths

- A delegate or block on the model; set it once, capture weakly.
- Key-value observing, as above, for `NSObject` models; remove every observer.
- `NSNotificationCenter` only for app-wide, loosely coupled events (account changed, store reset), not per-property updates. A block observer returns a token to store and remove.
- A store method that delivers an immutable snapshot of its state to a block on the main queue, called whenever it changes.

Whatever the path: coalesce bursts, and apply on the main thread from one method.

## Lists and model changes

- Identity and order: a snapshot built from the store's IDs.
- Content: reconfigure changed IDs when the store reports them. Cells look up their model by ID on each configuration pass; capturing the model object in a block keeps a stale reference after the item is replaced.
- Compositional layout section providers read traits and container size; on iOS 27 they also take part in Swift Observation tracking, which does not reach Objective-C properties (see the whats-new skill).

## Review checks

1. One source of truth; views read state, they do not keep copies.
2. Every state change reaches the view through `-setNeedsUpdateProperties`, `-setNeedsUpdateConfiguration` or a snapshot apply; nothing relies on tracking of an Objective-C property.
3. Property sets in `-updateProperties` (iOS 26+, guarded), geometry in `layoutSubviews`.
4. Observers added and removed in matching places; blocks use `weakSelf`.
5. Updates funnel through one main-thread method.
