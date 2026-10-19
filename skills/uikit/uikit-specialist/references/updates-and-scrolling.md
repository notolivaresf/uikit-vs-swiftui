# Updates and scrolling

Most visible list bugs are update bugs: the list jumps when older content loads, a new message does not scroll into view, a cell flashes because it was reloaded, or an update during a drag stutters. This file covers changing a list so the user notices only the change.

## Choose the right update

| Change | Do |
|---|---|
| Item content changed, same identity | `snapshot.reconfigureItems(ids)`, then apply |
| An item's cell type changed | `snapshot.reloadItems(ids)`, then apply |
| Items added, removed or moved | edit or build a snapshot; animate if the user caused it |
| Everything replaced (new account, new query) | apply without animation, or `applySnapshotUsingReloadData(_:)` |
| A cell's own height changed (expanded text) | `invalidateIntrinsicContentSize()` in the cell with `selfSizingInvalidation` on, or reconfigure |
| A purely visual effect on a visible cell (a pulse) | change that cell through `cellForItem(at:)`; leave the snapshot alone |

Wrong: `reloadData()` for a small change.

```swift
messages[index].isRead = true
collectionView.reloadData()
```

Right:

```swift
store[id]?.isRead = true
var snapshot = dataSource.snapshot()
snapshot.reconfigureItems([id])
dataSource.apply(snapshot, animatingDifferences: false)
```

Never call `performBatchUpdates`, `insertItems(at:)` or `reloadData()` on a collection view that has a diffable data source; the data source owns the updates.

## Coalesce bursts

When changes arrive many per second (a socket, a sync), collect them and apply one snapshot per short interval (50 to 100 ms) or per batch. Each apply diffs the whole snapshot, so many tiny applies cost more than one larger one, and each animated apply starts animations that the next one interrupts.

```swift
private var pending: [Change] = []
private var flushTask: Task<Void, Never>?

func receive(_ change: Change) {
    pending.append(change)
    guard flushTask == nil else { return }
    flushTask = Task { [weak self] in
        try? await Task.sleep(for: .milliseconds(80))
        self?.flush()
    }
}

private func flush() {
    flushTask = nil
    let changes = pending
    pending.removeAll()
    applyChanges(changes)          // one snapshot
}
```

Do not animate changes far from the visible area or during a fast scroll; the animation work is wasted and can hitch.

## Keeping position when content is inserted above

Inserting above the viewport (older messages, a new item at the top of a feed) grows content above what the user is reading, and everything visible moves down. Measure an anchor item before the update and put it back after.

Anchor on a visible item, not on `contentSize`. With estimated sizes the content size changes as cells are measured, so adding a size delta to the offset drifts.

```swift
@MainActor
func prependPreservingPosition(_ olderIDs: [ItemID]) async {
    // 1. The anchor: the first item whose top is visible, and its distance from the visible top.
    let visibleTop = collectionView.contentOffset.y + collectionView.adjustedContentInset.top
    let anchor = collectionView.indexPathsForVisibleItems
        .sorted()
        .lazy
        .compactMap { indexPath -> (ItemID, CGFloat)? in
            guard let attributes = self.collectionView.layoutAttributesForItem(at: indexPath),
                  attributes.frame.minY >= visibleTop,
                  let id = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            return (id, attributes.frame.minY - visibleTop)
        }
        .first

    // 2. Apply without animation.
    var snapshot = dataSource.snapshot()
    if let first = snapshot.itemIdentifiers(inSection: .messages).first {
        snapshot.insertItems(olderIDs, beforeItem: first)
    } else {
        snapshot.appendItems(olderIDs, toSection: .messages)
    }
    await dataSource.apply(snapshot, animatingDifferences: false)

    // 3. Put the anchor back.
    guard let (id, distance) = anchor,
          let indexPath = dataSource.indexPath(for: id) else { return }
    collectionView.layoutIfNeeded()
    guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return }
    let newOffset = attributes.frame.minY - distance - collectionView.adjustedContentInset.top
    collectionView.setContentOffset(CGPoint(x: 0, y: newOffset), animated: false)
}
```

- Measure, apply and restore with no animation and no suspension between apply and restore other than the apply itself, so no frame is drawn in a moved state.
- If the user is dragging or decelerating (`isDragging`, `isDecelerating`), setting the offset stops the scroll. Queue the prepend until the scroll ends, or start loading earlier so the insert lands while the user is still far from the top.
- Trigger loading before the user reaches the top: when the first visible index is within a screen of the start, or from prefetching.
- Cells inserted above the anchor are measured lazily. That is fine: only the anchor's final frame matters.

Wrong: an upside-down list for chat.

```swift
collectionView.transform = CGAffineTransform(scaleX: 1, y: -1)
// and each cell flipped back
```

It breaks VoiceOver order, context menu previews, scroll indicators, the keyboard dismiss gesture and accessibility scrolling. Keep natural order and anchor as above.

## Sticking to the bottom (chat and logs)

Track whether the user is at the bottom, and follow new content only when they are.

```swift
var isPinnedToBottom: Bool {
    let visibleBottom = collectionView.contentOffset.y + collectionView.bounds.height
        - collectionView.adjustedContentInset.bottom
    return visibleBottom >= collectionView.contentSize.height - 24
}

@MainActor
func append(_ newIDs: [ItemID]) async {
    let follow = isPinnedToBottom
    var snapshot = dataSource.snapshot()
    snapshot.appendItems(newIDs, toSection: .messages)
    await dataSource.apply(snapshot, animatingDifferences: follow)
    if follow, let last = newIDs.last, let indexPath = dataSource.indexPath(for: last) {
        collectionView.scrollToItem(at: indexPath, at: .bottom, animated: true)
    }
}
```

- Read "pinned" before the update; after it the content size has changed.
- When the keyboard rises the visible area shrinks from the bottom. If the user was pinned, keep them pinned: remember the state before the layout change and scroll to the last item when the collection view's height changes.
- First load of a long conversation: apply without animation, `layoutIfNeeded()`, scroll to the last item without animation, all before the view appears (in `viewIsAppearing(_:)`).
- When the user is not pinned, show a "new messages" control instead of moving them.

## Restoring a position across launches or reloads

Save the identifier of the top visible item and its offset from the visible top, not a raw `contentOffset`. After the next load, find that identifier's index path and use the restore step above. A raw offset is wrong as soon as anything above changes size, including after a text size change.

## Scrolling in code

- `scrollToItem(at:at:animated:)` works with estimated sizes, but a far target can land off by the estimate error. For an exact landing: scroll without animation, `layoutIfNeeded()`, then scroll to the same item again.
- Do not scroll in `viewDidLoad`; bounds are not final. Use `viewIsAppearing(_:)` or a point after the first layout.
- Await an animated `apply` before calling `scrollToItem` for an item it inserted.
- `UIScrollView` content offset changes in code do not call `scrollViewWillBeginDragging(_:)`; do not rely on delegate methods to detect your own scrolls.

## Scroll delegate hygiene

`scrollViewDidScroll(_:)` runs every frame while scrolling. Keep it to comparisons and cheap property sets. Never apply snapshots, force layout, or allocate heavily there.

For "load more", use prefetching (`list-performance.md`) or a check that fires once per threshold crossing:

```swift
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let nearTop = scrollView.contentOffset.y < scrollView.bounds.height
    if nearTop && !isLoadingOlder && hasOlder {
        isLoadingOlder = true
        loadOlderTask = Task { await loadOlder() }    // resets isLoadingOlder when done
    }
}
```

## Size changes

When the container width changes, cells resize and heights change, so the visible item moves. Save the anchor in `viewWillTransition(to:with:)` and restore it in the coordinator's animation or completion block with the same anchor method.

## Scroll edge effects (iOS 26+)

Scroll views draw an edge effect where content meets a bar. `topEdgeEffect`, `bottomEdgeEffect`, `leftEdgeEffect` and `rightEdgeEffect` are `UIScrollEdgeEffect` objects with a `style` (`.automatic`, `.soft`, `.hard`) and `isHidden`. Leave them on for scroll views under system bars. Hide one only when the edge never meets a bar.

## Review checks

1. No `reloadData()` or batch updates with a diffable data source.
2. Bursts coalesced into one apply.
3. Prepends restore an anchor item, not a content-size delta.
4. Chat stays in natural order; "pinned" checked before updates.
5. `scrollViewDidScroll(_:)` does only cheap work.
