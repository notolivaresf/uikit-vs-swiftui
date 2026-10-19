# Updates and scrolling

Most visible list bugs are update bugs: the list jumps when older content loads, a new message does not scroll into view, a cell flashes because it was reloaded, or an update during a drag stutters. This file covers changing a list so the user notices only the change.

## Choose the right update

| Change | Do |
|---|---|
| Item content changed, same identity | `[snapshot reconfigureItemsWithIdentifiers:ids]`, then apply |
| An item's cell type changed | `[snapshot reloadItemsWithIdentifiers:ids]`, then apply |
| Items added, removed or moved | edit or build a snapshot; animate if the user caused it |
| Everything replaced (new account, new query) | apply without animation, or `-applySnapshotUsingReloadData:` |
| A cell's own height changed (expanded text) | `-invalidateIntrinsicContentSize` in the cell with `selfSizingInvalidation` on, or reconfigure |
| A purely visual effect on a visible cell (a pulse) | change that cell through `-cellForItemAtIndexPath:`; leave the snapshot alone |

Wrong: `reloadData` for a small change.

```objc
self.messages[index].read = YES;
[self.collectionView reloadData];
```

Right:

```objc
self.store[itemID].read = YES;
NSDiffableDataSourceSnapshot<NSNumber *, NSUUID *> *snapshot = [self.dataSource snapshot];
[snapshot reconfigureItemsWithIdentifiers:@[itemID]];
[self.dataSource applySnapshot:snapshot animatingDifferences:NO];
```

Never call `performBatchUpdates:completion:`, `insertItemsAtIndexPaths:` or `reloadData` on a collection view that has a diffable data source; the data source owns the updates.

## Coalesce bursts

When changes arrive many per second (a socket, a sync), collect them and apply one snapshot per short interval (50 to 100 ms) or per batch. Each apply diffs the whole snapshot, so many tiny applies cost more than one larger one, and each animated apply starts animations that the next one interrupts.

```objc
- (void)receiveChange:(Change *)change {
    [self.pending addObject:change];
    if (self.flushScheduled) { return; }
    self.flushScheduled = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        [weakSelf flush];
    });
}

- (void)flush {
    self.flushScheduled = NO;
    NSArray<Change *> *changes = [self.pending copy];
    [self.pending removeAllObjects];
    [self applyChanges:changes];          // one snapshot
}
```

`dispatch_after` cannot be cancelled. If the screen can go away first, use a `dispatch_block_t` created with `dispatch_block_create` and cancel it with `dispatch_block_cancel`, or an `NSTimer` you invalidate in `viewDidDisappear:`, or `-performSelector:withObject:afterDelay:` paired with `+[NSObject cancelPreviousPerformRequestsWithTarget:selector:object:]`.

Do not animate changes far from the visible area or during a fast scroll; the animation work is wasted and can hitch.

## Keeping position when content is inserted above

Inserting above the viewport (older messages, a new item at the top of a feed) grows content above what the user is reading, and everything visible moves down. Measure an anchor item before the update and put it back after.

Anchor on a visible item, not on `contentSize`. With estimated sizes the content size changes as cells are measured, so adding a size delta to the offset drifts.

```objc
- (void)prependOlderIDs:(NSArray<NSUUID *> *)olderIDs {
    NSAssert([NSThread isMainThread], @"UIKit work belongs on the main thread");
    UICollectionView *cv = self.collectionView;

    // 1. The anchor: the first item whose top is visible, and its distance from the visible top.
    CGFloat visibleTop = cv.contentOffset.y + cv.adjustedContentInset.top;
    NSUUID *anchorID = nil;
    CGFloat distance = 0;
    NSArray<NSIndexPath *> *visible = [cv.indexPathsForVisibleItems sortedArrayUsingSelector:@selector(compare:)];
    for (NSIndexPath *indexPath in visible) {
        UICollectionViewLayoutAttributes *attributes = [cv layoutAttributesForItemAtIndexPath:indexPath];
        NSUUID *candidate = [self.dataSource itemIdentifierForIndexPath:indexPath];
        if (attributes && candidate && CGRectGetMinY(attributes.frame) >= visibleTop) {
            anchorID = candidate;
            distance = CGRectGetMinY(attributes.frame) - visibleTop;
            break;
        }
    }

    // 2. Apply without animation.
    NSDiffableDataSourceSnapshot<NSNumber *, NSUUID *> *snapshot = [self.dataSource snapshot];
    NSUUID *first = [snapshot itemIdentifiersInSectionWithIdentifier:@(SectionMessages)].firstObject;
    if (first) {
        [snapshot insertItemsWithIdentifiers:olderIDs beforeItemWithIdentifier:first];
    } else {
        [snapshot appendItemsWithIdentifiers:olderIDs intoSectionWithIdentifier:@(SectionMessages)];
    }
    __weak typeof(self) weakSelf = self;
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO completion:^{
        // 3. Put the anchor back.
        typeof(self) strongSelf = weakSelf;
        NSIndexPath *indexPath = anchorID ? [strongSelf.dataSource indexPathForItemIdentifier:anchorID] : nil;
        if (!indexPath) { return; }
        UICollectionView *view = strongSelf.collectionView;
        [view layoutIfNeeded];
        UICollectionViewLayoutAttributes *attributes = [view layoutAttributesForItemAtIndexPath:indexPath];
        if (!attributes) { return; }
        CGFloat newOffset = CGRectGetMinY(attributes.frame) - distance - view.adjustedContentInset.top;
        [view setContentOffset:CGPointMake(0, newOffset) animated:NO];
    }];
}
```

- Measure, apply and restore with no animation and nothing in between, so no frame is drawn in a moved state.
- If the user is dragging or decelerating (`isDragging`, `isDecelerating`), setting the offset stops the scroll. Queue the prepend until the scroll ends, or start loading earlier so the insert lands while the user is still far from the top.
- Trigger loading before the user reaches the top: when the first visible index is within a screen of the start, or from prefetching.
- Cells inserted above the anchor are measured lazily. That is fine: only the anchor's final frame matters.
- `anchorID` is a block-captured local (`__block` is not needed because it is not modified inside the block). Do not capture the index path.

Wrong: an upside-down list for chat.

```objc
self.collectionView.transform = CGAffineTransformMakeScale(1, -1);
// and each cell flipped back
```

It breaks VoiceOver order, context menu previews, scroll indicators, the keyboard dismiss gesture and accessibility scrolling. Keep natural order and anchor as above.

## Sticking to the bottom (chat and logs)

Track whether the user is at the bottom, and follow new content only when they are.

```objc
- (BOOL)isPinnedToBottom {
    UICollectionView *cv = self.collectionView;
    CGFloat visibleBottom = cv.contentOffset.y + CGRectGetHeight(cv.bounds) - cv.adjustedContentInset.bottom;
    return visibleBottom >= cv.contentSize.height - 24;
}

- (void)appendIDs:(NSArray<NSUUID *> *)newIDs {
    BOOL follow = [self isPinnedToBottom];
    NSDiffableDataSourceSnapshot<NSNumber *, NSUUID *> *snapshot = [self.dataSource snapshot];
    [snapshot appendItemsWithIdentifiers:newIDs intoSectionWithIdentifier:@(SectionMessages)];
    __weak typeof(self) weakSelf = self;
    [self.dataSource applySnapshot:snapshot animatingDifferences:follow completion:^{
        NSUUID *last = newIDs.lastObject;
        NSIndexPath *indexPath = last ? [weakSelf.dataSource indexPathForItemIdentifier:last] : nil;
        if (follow && indexPath) {
            [weakSelf.collectionView scrollToItemAtIndexPath:indexPath
                                            atScrollPosition:UICollectionViewScrollPositionBottom
                                                    animated:YES];
        }
    }];
}
```

- Read "pinned" before the update; after it the content size has changed.
- When the keyboard rises the visible area shrinks from the bottom. If the user was pinned, keep them pinned: remember the state before the layout change and scroll to the last item when the collection view's height changes.
- First load of a long conversation: apply without animation, `layoutIfNeeded`, scroll to the last item without animation, all before the view appears (in `viewIsAppearing:`).
- When the user is not pinned, show a "new messages" control instead of moving them.

## Restoring a position across launches or reloads

Save the identifier of the top visible item and its offset from the visible top, not a raw `contentOffset`. After the next load, find that identifier's index path and use the restore step above. A raw offset is wrong as soon as anything above changes size, including after a text size change.

## Scrolling in code

- `-scrollToItemAtIndexPath:atScrollPosition:animated:` works with estimated sizes, but a far target can land off by the estimate error. For an exact landing: scroll without animation, `layoutIfNeeded`, then scroll to the same item again.
- Do not scroll in `viewDidLoad`; bounds are not final. Use `viewIsAppearing:` or a point after the first layout.
- Wait for the `completion:` of an animated apply before scrolling to an item it inserted.
- Content offset changes in code do not call `scrollViewWillBeginDragging:`; do not rely on delegate methods to detect your own scrolls.

## Scroll delegate hygiene

`scrollViewDidScroll:` runs every frame while scrolling. Keep it to comparisons and cheap property sets. Never apply snapshots, force layout, or allocate heavily there.

For "load more", use prefetching (`list-performance.md`) or a check that fires once per threshold crossing:

```objc
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    BOOL nearTop = scrollView.contentOffset.y < CGRectGetHeight(scrollView.bounds);
    if (nearTop && !self.loadingOlder && self.hasOlder) {
        self.loadingOlder = YES;
        [self loadOlder];          // sets loadingOlder = NO in its completion block
    }
}
```

## Size changes

When the container width changes, cells resize and heights change, so the visible item moves. Save the anchor in `viewWillTransitionToSize:withTransitionCoordinator:` and restore it in the coordinator's `animateAlongsideTransition:completion:` completion block with the same anchor method.

## Scroll edge effects (iOS 26+)

Scroll views draw an edge effect where content meets a bar. `topEdgeEffect`, `bottomEdgeEffect`, `leftEdgeEffect` and `rightEdgeEffect` are `UIScrollEdgeEffect` objects with a `style` (`UIScrollEdgeEffectStyle`: `+automaticStyle`, `+softStyle`, `+hardStyle`) and `hidden`. Leave them on for scroll views under system bars. Hide one only when the edge never meets a bar.

## Review checks

1. No `reloadData` or batch updates with a diffable data source.
2. Bursts coalesced into one apply.
3. Prepends restore an anchor item, not a content-size delta.
4. Chat stays in natural order; "pinned" checked before updates.
5. `scrollViewDidScroll:` does only cheap work.
6. Delayed blocks capture `weakSelf` and can be cancelled.
