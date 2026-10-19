# Swift concurrency with UIKit

UIKit is a main-thread framework. `UIView`, `UIViewController`, `UIApplication` and most UIKit protocols are `@MainActor`, so in Swift 6 the compiler enforces what used to be a runtime rule. Keep UI on the main actor, move work off it, and make the boundary explicit.

## The shape that works

```swift
final class FeedViewController: UIViewController {
    private let service: FeedService            // an actor or a Sendable type
    private var loadTask: Task<Void, Never>?

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        guard loadTask == nil else { return }
        loadTask = Task { [weak self] in
            await self?.load()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        loadTask?.cancel()
        loadTask = nil
    }

    private func load() async {
        do {
            let page = try await service.firstPage()   // runs on the service's actor
            try Task.checkCancellation()
            apply(page)                                 // back on the main actor
        } catch is CancellationError {
            // the screen went away
        } catch {
            showError(error)
        }
    }
}
```

- A `Task { }` created in a main-actor type inherits the main actor. Awaiting a call into another actor suspends the main actor's work while the call runs elsewhere, then resumes on main. No `DispatchQueue.main.async` or `MainActor.run` is needed.
- Store the task and cancel it when the result is no longer wanted. A task is not tied to the controller's lifetime; it keeps running and keeps what it captures alive until it ends.
- Capture `[weak self]` in tasks that may outlive the screen. A short task that must finish (saving a draft) can capture strongly.
- Check cancellation after each suspension that precedes UI work.

Wrong: hopping manually and never cancelling.

```swift
DispatchQueue.global().async {
    let page = try? self.service.loadSync()
    DispatchQueue.main.async { self.apply(page) }
}
```

## Moving work off the main actor

`async` does not mean "background". An `async` method on a main-actor class runs on the main actor between suspensions. To move CPU work off main:

- Put it in an actor (`actor ImageCache`, `actor Database`) or a type that is not main-actor isolated.
- Or mark a function `@concurrent` (Swift 6.2+). In Swift 6.2 with the "approachable concurrency" settings, a `nonisolated async` function runs on the caller's actor unless marked `@concurrent`. Check the project's Swift version, its upcoming-feature flags, and the "Default Actor Isolation" build setting (it can make every type `@MainActor` by default) before relying on either rule.
- Use `Task.detached` rarely, when you must drop the current actor and priority on purpose.

Pass `Sendable` values across the boundary: value types, IDs, `Data`, immutable final classes. `UIImage` is `Sendable`. Do not send views or non-Sendable model classes into another actor.

## Streams and long-lived updates

Consume an `AsyncSequence` (a socket, a database observation, `NotificationCenter.default.notifications(named:)`) in a stored task and apply changes in batches:

```swift
streamTask = Task { [weak self] in
    guard let batches = self?.service.updateBatches() else { return }   // AsyncStream<[Change]>
    for await batch in batches {
        guard let self else { return }
        self.applyChanges(batch)
    }
}
```

One snapshot apply per batch keeps the main actor free for scrolling. Batch in the producer (collect and yield every 50 to 100 ms or every N items). Re-checking `self` per element lets the screen go away mid-stream.

## Delegates, callbacks and older APIs

- UIKit delegate protocols are main-actor isolated; your conformances run on main.
- Callbacks from other frameworks may arrive on any queue. If the API is not annotated, hop with `Task { @MainActor in ... }` or mark the closure `@MainActor`. Wrap one-shot callback APIs with `withCheckedContinuation` once, in the service layer.
- `@preconcurrency import` silences warnings from modules not yet annotated. Prefer it to `@unchecked Sendable` on your own types.
- `nonisolated` on a method of a main-actor class lets it be called from anywhere, but it then cannot touch views or main-actor state.
- `deinit` of a main-actor class is nonisolated unless declared `isolated deinit` (Swift 6.2+); do not touch views there. Cancel tasks from `viewDidDisappear` or from an explicit teardown instead of relying on `deinit`.

## Per-cell tasks

- One task per cell, stored on the cell, cancelled in `prepareForReuse()`.
- After the await, check `Task.isCancelled` and that the cell still represents the same identifier (see `list-performance.md`).
- Do not start a task per configuration pass without cancelling the previous one; they pile up during fast scrolling.

## Things that cause hangs or crashes

- `DispatchQueue.main.sync` from the main thread deadlocks.
- Semaphores or `DispatchGroup.wait()` to make async code synchronous on main freeze the UI and can deadlock with the main actor.
- Touching a view from a background queue: the Main Thread Checker catches it in Debug; strict concurrency checking catches most at compile time. Use complete checking in new code.
- Large `@MainActor` model classes that parse or sort inside their methods: the work runs on main. Move it to an actor and return results.
- `Data(contentsOf:)` or synchronous file reads for network URLs or large files on main.
- `Thread.sleep` or busy-waiting anywhere on main.

## Review checks

1. UI work on the main actor; CPU work in actors or `@concurrent` functions.
2. Tasks stored and cancelled; weak captures for long ones.
3. Cancellation checked before UI updates.
4. Streams applied in batches.
5. No `main.sync`, semaphores or synchronous I/O on main.
