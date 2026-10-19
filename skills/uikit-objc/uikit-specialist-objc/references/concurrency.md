# Concurrency and memory in Objective-C UIKit

UIKit is a main-thread framework. Swift concurrency (`async`, `await`, actors, `Sendable`, `@concurrent`, `Task`) does not exist in Objective-C. What applies instead is Grand Central Dispatch, `NSOperationQueue`, `NSURLSession` completion handlers, blocks and ARC. This file also covers the block memory traps agents hit most, and how the Objective-C annotations look to Swift callers.

## The shape that works

```objc
@interface FeedViewController ()
@property (nonatomic, strong) FeedService *service;
@property (nonatomic, strong, nullable) NSURLSessionTask *loadTask;
@end

@implementation FeedViewController

- (void)viewIsAppearing:(BOOL)animated {
    [super viewIsAppearing:animated];
    if (self.loadTask) { return; }
    __weak typeof(self) weakSelf = self;
    self.loadTask = [self.service loadFirstPageWithCompletion:^(NSArray<FeedItem *> * _Nullable page, NSError * _Nullable error) {
        // arrives on the service's queue
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) { return; }
            strongSelf.loadTask = nil;
            if (error) {
                if (error.code != NSURLErrorCancelled) { [strongSelf showError:error]; }
                return;
            }
            [strongSelf applyPage:page];
        });
    }];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.loadTask cancel];
    self.loadTask = nil;
}
@end
```

- Return and store the cancellable thing (`NSURLSessionTask`, `NSOperation`, a `dispatch_block_t` made with `dispatch_block_create`) so the screen can cancel it when the result is no longer wanted. A request keeps running, and keeps whatever its block captured alive, until it ends.
- A cancelled `NSURLSessionTask` calls its completion with `NSURLErrorCancelled`; do not show that as an error.
- Hop to the main queue before touching UIKit. State where each block runs in the method name or a comment ("completion on the main queue").

## Retain cycles with blocks

A block that uses `self` (or an ivar, which is `self->_ivar`) retains `self`. If `self` also retains the block, directly or through an object it owns, neither is ever freed.

Wrong:

```objc
self.dataSource = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView
    cellProvider:^UICollectionViewCell *(UICollectionView *cv, NSIndexPath *ip, NSUUID *itemID) {
    return [cv dequeueConfiguredReusableCellWithRegistration:self.registration forIndexPath:ip item:itemID];  // self -> dataSource -> block -> self
}];
```

Right: weak outside, strong inside, check for `nil`.

```objc
__weak typeof(self) weakSelf = self;
self.onChange = ^(Model *model) {
    typeof(self) strongSelf = weakSelf;
    if (!strongSelf) { return; }
    [strongSelf render:model];       // strongSelf lives for the whole block
};
```

- Common owners that keep blocks: a `copy` property on the controller or a cell, a registration handler, a data source provider, a `UIAction` handler on a button the controller owns, `configurationUpdateHandler`, an `NSNotificationCenter` block observer, a `CADisplayLink` target, a repeating `NSTimer`.
- One-shot blocks that are not stored (`dispatch_async`, `[UIView animateWithDuration:...]`) retain `self` only until they run, so a strong capture is fine there. Stored blocks and repeating observers need `weakSelf`.
- Do not write `__weak` and then dereference `weakSelf->_ivar` without a strong local: that crashes on `nil` and is not atomic. Use the strong local.
- A block observer from `-addObserverForName:object:queue:usingBlock:` returns a token. Store it and call `-removeObserver:` on the token in `viewDidDisappear:` or `dealloc`; the notification center keeps the block alive until you do.
- `NSTimer` retains its target. Use the block form `+scheduledTimerWithTimeInterval:repeats:block:` with `weakSelf`, and call `invalidate` when the screen goes away.
- Delegates are `weak` (or `assign` for non-object types). A strong delegate property is a cycle.
- Find cycles with Xcode's Debug Memory Graph and the Leaks instrument, and by putting a log line or breakpoint in `dealloc` of every controller while developing.

## Property attributes that matter

- Block properties are `copy`: `@property (nonatomic, copy, nullable) void (^onDone)(void);`. Under ARC `strong` also works, but `copy` is the convention and moves a stack block to the heap.
- `NSString`, `NSArray`, `NSDictionary`, `NSSet` and `NSData` properties are `copy`, so a caller passing a mutable subclass cannot change the value later.
- Outlets and subviews you own: `strong` or `weak` consistently (`weak` for views owned by the view hierarchy).
- Add `nonnull` and `nullable` to every declaration, or wrap headers in `NS_ASSUME_NONNULL_BEGIN` and `NS_ASSUME_NONNULL_END` and mark the exceptions. Use lightweight generics on every collection (`NSArray<NSString *> *`, `NSDictionary<NSUUID *, Message *> *`).

## Main-thread rules

- UIKit calls come from the main thread only. The Main Thread Checker reports violations in Debug; enable it.
- Hop with `dispatch_async(dispatch_get_main_queue(), ^{ ... })`. When you might already be on main and need the code to run now, check first:

  ```objc
  void RunOnMain(dispatch_block_t block) {
      if ([NSThread isMainThread]) { block(); } else { dispatch_async(dispatch_get_main_queue(), block); }
  }
  ```

- `dispatch_sync(dispatch_get_main_queue(), ...)` from the main thread deadlocks. Never use it from code that may run on main.
- To assert a precondition in code that must be on main: `NSAssert([NSThread isMainThread], @"...")` or `dispatch_assert_queue(dispatch_get_main_queue())`.
- `-performSelector:withObject:afterDelay:` runs on the current thread's run loop and holds a strong reference to its target and argument. Cancel it before the target goes away with `+[NSObject cancelPreviousPerformRequestsWithTarget:selector:object:]` (or `+cancelPreviousPerformRequestsWithTarget:` for all selectors on that target). Selector-based performs with a non-object return type or arguments of the wrong type fail silently or crash; prefer a block.
- Prefer `dispatch_after` with a weak capture for one-shot delays that need no cancellation, and a cancellable block or `NSTimer` otherwise.

## Moving work off the main thread

- CPU and I/O go on a global queue or a private serial queue: `dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ ... })`. Use a serial queue created with `dispatch_queue_create` to protect mutable state, instead of locks scattered around.
- `NSOperationQueue` with `maxConcurrentOperationCount` when you need cancellation, dependencies or limits. Check `isCancelled` inside long operations.
- Shared mutable state (`NSMutableArray`, `NSMutableDictionary`) is not thread-safe. Confine it to one queue, or copy and pass immutable snapshots across threads.
- Pass immutable values across the boundary: `NSString`, `NSNumber`, `NSUUID`, `NSData`, immutable model objects. Do not hand views, or mutable arrays you keep editing, to another queue.
- `atomic` properties (the default if you write nothing) protect only the accessor, not the sequence of calls you make. Mark UI properties `nonatomic`.

## Streams and long-lived updates

Callbacks that arrive many times per second (a socket, a database observation, a notification) should be collected and applied in batches: gather on the producer queue, then `dispatch_async` to main once per 50 to 100 ms or per N items, and apply one snapshot (see `updates-and-scrolling.md`). Remove the observer or close the stream when the screen goes away; a block that keeps firing into a deallocated controller is a crash if it was captured unsafely.

## Swift interop of your Objective-C

If a Swift module imports your Objective-C headers, annotate them:

- `NS_SWIFT_UI_ACTOR` on a class or protocol that must be used from the main actor (view controllers, views, UI helpers). UIKit's own headers use it, so Swift sees `UIView` as main-actor isolated. Swift 6 callers then need `@MainActor` or `await` to reach it.
- `NS_SWIFT_NONISOLATED` on a member (or on a notification-name constant) that is safe from any thread. Without it a member of a main-actor class stays main-actor isolated.
- `NS_SWIFT_SENDABLE` on immutable data classes that are safe to send between actors.
- A completion-handler method whose handler returns once, with an `NSError *` last, is imported into Swift as `async throws` automatically. If the handler may be called more than once or on a particular queue, add `NS_SWIFT_DISABLE_ASYNC`, and document the queue.
- Say which queue calls each completion block in the header comment. Callers cannot guess.

Swift concurrency itself cannot be used from `.m` files. If you need Swift async code, wrap it in a Swift class exposed with `@objc` that offers completion-handler methods, and call that from Objective-C.

## Per-cell work

- One request per cell, kept so `-prepareForReuse` can cancel it.
- After the callback, check that the cell still represents the same identifier (see `list-performance.md`).
- Do not start a request per configuration pass without cancelling the previous one; they pile up during fast scrolling.

## Things that cause hangs or crashes

- `dispatch_sync` onto the queue you are already on, and `dispatch_sync` to main from main.
- Semaphores or `dispatch_group_wait` to make async code synchronous on main freeze the UI.
- Touching a view from a background queue: the Main Thread Checker catches it in Debug.
- Large model classes that parse or sort inside methods called on main: move the work to a queue and return results.
- `+[NSData dataWithContentsOfURL:]` or synchronous file reads for network URLs or large files on main.
- `[NSThread sleepForTimeInterval:]` or busy-waiting anywhere on main.
- Unbalanced KVO: `-addObserver:forKeyPath:options:context:` without a matching `-removeObserver:forKeyPath:context:` crashes on dealloc of the observed object. For new code prefer a delegate, a callback block, or a notification observer whose token you store and remove.

## Review checks

1. UI work on the main thread; CPU and I/O on queues.
2. Stored blocks use `weakSelf`; delegates are weak; block and string properties are `copy`.
3. Cancellable work stored and cancelled; observers removed.
4. Streams applied in batches.
5. No `dispatch_sync` to main, semaphores or synchronous I/O on main.
6. Headers annotated for nullability, generics and, where Swift imports them, actor isolation.
