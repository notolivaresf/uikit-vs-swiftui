# Animation and transitions

UIKit animations describe an end state; the render server interpolates. Change properties inside an animation block, keep the model as the source of truth, and let gestures interrupt.

## Choosing an API

| Need | Use |
|---|---|
| A one-shot change of view properties | `UIView.animate(withDuration:delay:options:animations:completion:)` |
| A natural, physical change | `UIView.animate(springDuration:bounce:initialSpringVelocity:delay:options:animations:completion:)` (iOS 17+) |
| Interruptible, scrubbable, reversible, or driven by a gesture | `UIViewPropertyAnimator` |
| A symbol that bounces, pulses or changes | symbol effects on `UIImageView` and bar items (iOS 17+) |
| A cell-to-detail transition | `preferredTransition = .zoom(...)` (iOS 18+), see `navigation-and-bars.md` |
| Swapping a view's content | `UIView.transition(with:duration:options:animations:completion:)` with `.transitionCrossDissolve` |
| Per-frame drawing that no animation covers | `UIUpdateLink` (iOS 18+) |

## Springs

Springs are the default choice for movement. Describe them with duration and bounce, not mass and stiffness.

```swift
UIView.animate(springDuration: 0.4, bounce: 0.15) {
    self.panel.transform = .identity
    self.panel.alpha = 1
}
```

- `bounce` 0 is critically damped (no overshoot); 0.1 to 0.3 is a gentle settle. Negative values are overdamped.
- Pass the gesture's velocity in `initialSpringVelocity` when an animation continues a drag, so there is no jump in speed. Velocity there is relative to the remaining distance: divide the gesture's points per second by the distance left.
- `UISpringTimingParameters(duration:bounce:)` (iOS 17+) builds the same spring for a property animator.

## Animating layout

Animate constraint changes by changing the constraint, then laying out inside the block.

Wrong: animating the constant alone.

```swift
UIView.animate(withDuration: 0.3) {
    self.heightConstraint.constant = 200
}
```

Right:

```swift
heightConstraint.constant = 200
UIView.animate(withDuration: 0.3) {
    self.view.layoutIfNeeded()          // the common ancestor of everything that moves
}
```

On iOS 26 and later, `.flushUpdates` in the animation options applies pending layout and property updates inside the animation, so the explicit `layoutIfNeeded()` is not needed, and observable model changes made in the block animate too:

```swift
UIView.animate(withDuration: 0.3, delay: 0, options: .flushUpdates) {
    self.heightConstraint.constant = 200
}
```

## Property animators

Use `UIViewPropertyAnimator` when the animation must respond to the user.

```swift
let animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: UISpringTimingParameters(duration: 0.5, bounce: 0))
animator.addAnimations { self.sheet.transform = .identity }
animator.pauseAnimation()

// in the pan handler
switch gesture.state {
case .changed:
    animator.fractionComplete = progress(for: gesture)
case .ended, .cancelled:
    let shouldFinish = progress(for: gesture) > 0.5 || velocity(for: gesture) > 500
    animator.isReversed = !shouldFinish
    animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
default:
    break
}
```

- An animator runs once. Make a new one for the next interaction, or keep one with `pausesOnCompletion = true` to reverse it later.
- Stop a running animator before starting a conflicting one: `stopAnimation(false)` then `finishAnimation(at: .current)`, or let `isInterruptible` (default true) hand over.
- `scrubsLinearly` and `isManualHitTestingEnabled` adjust scrubbing and touches during the animation.
- iOS 26: the animator's `flushUpdates` property matches the animation option above.

## Interruptions and model state

- Set the model to the end state when the animation starts, not in the completion handler. Completion may run with `finished == false` when another animation interrupts.
- Starting a new animation on the same property from its current presentation value happens automatically with `.beginFromCurrentState` (implied in spring and property-animator APIs).
- Do not read `frame` during an animation to decide layout; it is already the end value. The on-screen value is `layer.presentation()`.
- Avoid nested completion chains for sequences; use `UIView.animateKeyframes(withDuration:delay:options:animations:)` with `addKeyframe(withRelativeStartTime:relativeDuration:animations:)`, or one property animator with several `addAnimations(_:delayFactor:)`.

## Symbol effects (iOS 17+)

```swift
imageView.addSymbolEffect(.bounce)                                  // one-shot
imageView.addSymbolEffect(.pulse, options: .repeating)              // until removed
imageView.removeSymbolEffect(ofType: .pulse)
imageView.setSymbolImage(UIImage(systemName: "checkmark.circle.fill")!, contentTransition: .replace)
```

- Effects include `.bounce`, `.pulse`, `.variableColor`, `.scale`, `.appear`, `.disappear`, `.replace`, and on iOS 18 `.wiggle`, `.rotate` and `.breathe`.
- `UIBarButtonItem` has the same `addSymbolEffect` and `setSymbolImage(_:contentTransition:)` methods.
- Prefer a symbol effect over hand-made scale animations on icons; it respects accessibility settings.

## Content changes in lists

- Animated snapshot applies animate inserts, deletes and moves. Do not wrap `apply` in `UIView.animate`; pass `animatingDifferences`.
- To animate a self-sizing height change, change the content inside `UIView.animate` and let self-sizing invalidation resize the cell, or reconfigure with animation.

## Custom transitions

- For push and present, try the zoom transition and standard styles first.
- A custom transition uses `UIViewControllerTransitioningDelegate` (present) or `UINavigationControllerDelegate` (push) returning a `UIViewControllerAnimatedTransitioning`. Make the animation with a property animator and return it from `interruptibleAnimator(using:)` so the transition can be interrupted.
- Interactive transitions drive a `UIPercentDrivenInteractiveTransition` from a gesture; call `finish()` or `cancel()` at the end and always call `completeTransition(_:)` with `!transitionContext.transitionWasCancelled`.
- Snapshot views (`snapshotView(afterScreenUpdates: false)`) are cheap stand-ins for moving content during a transition.

## Reduce Motion

Check `UIAccessibility.isReduceMotionEnabled` and listen for `UIAccessibility.reduceMotionStatusDidChangeNotification`.

- Replace movement, zooms and parallax with fades.
- Keep functional animation (a progress indicator), drop decorative motion.
- `UIAccessibility.prefersCrossFadeTransitions` asks for cross-fades instead of slides in transitions.
- System animations (navigation, sheets, symbol effects) already adapt.

```swift
let reduce = UIAccessibility.isReduceMotionEnabled
UIView.animate(springDuration: reduce ? 0.2 : 0.45, bounce: reduce ? 0 : 0.2) {
    if reduce { self.card.alpha = 1 } else { self.card.transform = .identity; self.card.alpha = 1 }
}
```

## Performance

- Animate `transform` and `alpha` rather than `frame` or constraints when only the visual position changes; they do not trigger layout.
- Avoid animating shadows without a `shadowPath`, and masks over large areas.
- Do not drive animations with timers or `scrollViewDidScroll(_:)` writes to many views; use property animators or layout-based effects.

## Review checks

1. Springs for movement, described with duration and bounce.
2. Constraint animations lay out the common ancestor (or use `.flushUpdates` on iOS 26+).
3. Model updated at the start, not in completion.
4. Gesture-driven animations use property animators and can be interrupted.
5. Reduce Motion handled for decorative movement.
