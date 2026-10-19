# Animation and transitions

UIKit animations describe an end state; the render server interpolates. Change properties inside an animation block, keep the model as the source of truth, and let gestures interrupt. Animation blocks run once, immediately or at the next run loop pass, so a strong `self` in them is harmless; a block stored in a property is not.

## Choosing an API

| Need | Use |
|---|---|
| A one-shot change of view properties | `+[UIView animateWithDuration:delay:options:animations:completion:]` |
| A natural, physical change | `+[UIView animateWithSpringDuration:bounce:initialSpringVelocity:delay:options:animations:completion:]` (iOS 17+) |
| Interruptible, scrubbable, reversible, or driven by a gesture | `UIViewPropertyAnimator` |
| A symbol that bounces, pulses or changes | `-addSymbolEffect:` on `UIImageView` and bar items (iOS 17+) |
| A cell-to-detail transition | `preferredTransition` set to a zoom transition (iOS 18+), see `navigation-and-bars.md` |
| Swapping a view's content | `+[UIView transitionWithView:duration:options:animations:completion:]` with `UIViewAnimationOptionTransitionCrossDissolve` |
| Per-frame drawing that no animation covers | `UIUpdateLink` (iOS 18+) |

## Springs

Springs are the default choice for movement. Describe them with duration and bounce, not mass and stiffness.

```objc
[UIView animateWithSpringDuration:0.4 bounce:0.15 initialSpringVelocity:0 delay:0 options:0 animations:^{
    self.panel.transform = CGAffineTransformIdentity;
    self.panel.alpha = 1;
} completion:nil];
```

- `bounce` 0 is critically damped (no overshoot); 0.1 to 0.3 is a gentle settle. Negative values are overdamped.
- Pass the gesture's velocity in `initialSpringVelocity` when an animation continues a drag, so there is no jump in speed. Velocity there is relative to the remaining distance: divide the gesture's points per second by the distance left.
- `[[UISpringTimingParameters alloc] initWithDuration:bounce:]` (iOS 17+) builds the same spring for a property animator.

## Animating layout

Animate constraint changes by changing the constraint, then laying out inside the block.

Wrong: animating the constant alone.

```objc
[UIView animateWithDuration:0.3 animations:^{
    self.heightConstraint.constant = 200;
}];
```

Right:

```objc
self.heightConstraint.constant = 200;
[UIView animateWithDuration:0.3 animations:^{
    [self.view layoutIfNeeded];          // the common ancestor of everything that moves
}];
```

On iOS 26 and later, `UIViewAnimationOptionFlushUpdates` applies pending layout and property updates inside the animation, so the explicit `layoutIfNeeded` is not needed:

```objc
[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionFlushUpdates animations:^{
    self.heightConstraint.constant = 200;
} completion:nil];
```

Guard it with `@available(iOS 26.0, *)`; on older systems the option value is ignored and nothing animates.

## Property animators

Use `UIViewPropertyAnimator` when the animation must respond to the user. Store the animator in a `strong` property.

```objc
UISpringTimingParameters *spring = [[UISpringTimingParameters alloc] initWithDuration:0.5 bounce:0];
self.animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.5 timingParameters:spring];
[self.animator addAnimations:^{ self.sheet.transform = CGAffineTransformIdentity; }];
[self.animator pauseAnimation];

// in the pan handler
switch (gesture.state) {
    case UIGestureRecognizerStateChanged:
        self.animator.fractionComplete = [self progressForGesture:gesture];
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled: {
        BOOL shouldFinish = [self progressForGesture:gesture] > 0.5 || [self velocityForGesture:gesture] > 500;
        self.animator.reversed = !shouldFinish;
        [self.animator continueAnimationWithTimingParameters:nil durationFactor:0];
        break;
    }
    default:
        break;
}
```

- An animator runs once. Make a new one for the next interaction, or keep one with `pausesOnCompletion = YES` to reverse it later.
- Stop a running animator before starting a conflicting one: `[animator stopAnimation:NO]` then `[animator finishAnimationAtPosition:UIViewAnimatingPositionCurrent]`, or let `interruptible` (default `YES`) hand over. Releasing an animator that is neither stopped nor finished raises an exception.
- `scrubsLinearly` and `manualHitTestingEnabled` adjust scrubbing and touches during the animation.
- iOS 26: the animator's `flushUpdates` property matches the animation option above.
- Completion blocks added with `addCompletion:` take a `UIViewAnimatingPosition`; do not assume `UIViewAnimatingPositionEnd`.

## Interruptions and model state

- Set the model to the end state when the animation starts, not in the completion block. Completion may run with `finished == NO` when another animation interrupts.
- Starting a new animation on the same property from its current presentation value happens automatically with `UIViewAnimationOptionBeginFromCurrentState` (implied in spring and property-animator APIs).
- Do not read `frame` during an animation to decide layout; it is already the end value. The on-screen value is `layer.presentationLayer`.
- Avoid nested completion chains for sequences; use `+animateKeyframesWithDuration:delay:options:animations:completion:` with `+addKeyframeWithRelativeStartTime:relativeDuration:animations:`, or one property animator with several `addAnimations:delayFactor:`.

## Symbol effects (iOS 17+)

Effect classes live in the Symbols framework (imported with UIKit): `NSSymbolBounceEffect`, `NSSymbolPulseEffect`, `NSSymbolVariableColorEffect`, `NSSymbolScaleEffect`, `NSSymbolAppearEffect`, `NSSymbolDisappearEffect`, `NSSymbolWiggleEffect` (iOS 18) and others, each created with `+effect`.

```objc
[imageView addSymbolEffect:[NSSymbolBounceEffect effect]];                          // one-shot
[imageView addSymbolEffect:[NSSymbolPulseEffect effect]
                   options:[NSSymbolEffectOptions optionsWithRepeatBehavior:
                            [NSSymbolEffectOptionsRepeatBehavior behaviorPeriodic]]];   // until removed
[imageView removeSymbolEffectOfType:[NSSymbolPulseEffect effect]];
[imageView setSymbolImage:[UIImage systemImageNamed:@"checkmark.circle.fill"]
    withContentTransition:[NSSymbolReplaceContentTransition replaceDownUpTransition]];
```

- `+optionsWithRepeating` is deprecated; use `optionsWithRepeatBehavior:`.
- Effects include bounce, pulse, variable color, scale, appear, disappear, replace, and on iOS 18 wiggle, rotate and breathe.
- `UIBarButtonItem` has the same `-addSymbolEffect:` and `-setSymbolImage:withContentTransition:` methods.
- Prefer a symbol effect over hand-made scale animations on icons; it respects accessibility settings.
- Symbol effects do not exist before iOS 17: guard with `@available(iOS 17.0, *)` if the target is lower.

## Content changes in lists

- Animated snapshot applies animate inserts, deletes and moves. Do not wrap `applySnapshot:` in `+animateWithDuration:...`; pass `animatingDifferences:`.
- To animate a self-sizing height change, change the content inside an animation block and let self-sizing invalidation resize the cell, or reconfigure with animation.

## Custom transitions

- For push and present, try the zoom transition and standard styles first.
- A custom transition uses `UIViewControllerTransitioningDelegate` (present) or `UINavigationControllerDelegate` (push) returning an object that conforms to `UIViewControllerAnimatedTransitioning`. Make the animation with a property animator and return it from `interruptibleAnimatorForTransition:` so the transition can be interrupted.
- Interactive transitions drive a `UIPercentDrivenInteractiveTransition` from a gesture; call `finishInteractiveTransition` or `cancelInteractiveTransition` at the end and always call `completeTransition:` with `![transitionContext transitionWasCancelled]`.
- Snapshot views (`-snapshotViewAfterScreenUpdates:NO`) are cheap stand-ins for moving content during a transition.
- The delegate that vends the animator is held weakly by the presenting controller; keep your own strong reference to the transition object.

## Reduce Motion

Check `UIAccessibilityIsReduceMotionEnabled()` and observe `UIAccessibilityReduceMotionStatusDidChangeNotification`.

- Replace movement, zooms and parallax with fades.
- Keep functional animation (a progress indicator), drop decorative motion.
- `UIAccessibilityPrefersCrossFadeTransitions()` asks for cross-fades instead of slides in transitions.
- System animations (navigation, sheets, symbol effects) already adapt.

```objc
BOOL reduce = UIAccessibilityIsReduceMotionEnabled();
[UIView animateWithSpringDuration:reduce ? 0.2 : 0.45 bounce:reduce ? 0 : 0.2 initialSpringVelocity:0 delay:0 options:0 animations:^{
    if (!reduce) { self.card.transform = CGAffineTransformIdentity; }
    self.card.alpha = 1;
} completion:nil];
```

## Performance

- Animate `transform` and `alpha` rather than `frame` or constraints when only the visual position changes; they do not trigger layout.
- Avoid animating shadows without a `shadowPath`, and masks over large areas.
- Do not drive animations with timers or `scrollViewDidScroll:` writes to many views; use property animators or layout-based effects.

## Review checks

1. Springs for movement, described with duration and bounce.
2. Constraint animations lay out the common ancestor (or use `UIViewAnimationOptionFlushUpdates` on iOS 26+, guarded).
3. Model updated at the start, not in completion.
4. Gesture-driven animations use property animators held in a property, and can be interrupted.
5. Reduce Motion handled for decorative movement.
