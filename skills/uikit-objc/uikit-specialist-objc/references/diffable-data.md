# Diffable data sources and item identity

A diffable data source shows a snapshot: an ordered list of section identifiers and item identifiers. When you apply a new snapshot, UIKit compares it with the old one by identity and animates the inserts, deletes and moves. Everything in this file follows from that: the identifier is the item's identity, and identity decides animation, cell reuse, selection, scroll anchoring and performance.

## What makes a good identifier

In Objective-C an identifier is an object that implements `isEqual:` and `hash` (the generic parameters are `NSObject` subclasses, or any `id` that behaves like one). An identifier must be:

- **Stable**: the same item has the same identifier across every snapshot, for as long as it exists.
- **Unique**: no two items in one snapshot share it. Duplicates raise an exception when the snapshot is applied.
- **Small and cheap to hash**: the diff hashes every identifier on each apply.
- **Immutable**: a mutable object whose `hash` changes while it sits in a snapshot corrupts the diff. Use `NSUUID`, `NSString`, `NSNumber`, or an immutable class with `readonly` properties.

The best identifier is the model's own ID: a database key, a server ID, a `NSUUID` assigned once when the model is created.

```objc
typedef NS_ENUM(NSInteger, MessageSection) { MessageSectionPinned, MessageSectionRecent };

// Section identifiers: boxed enum values. Item identifiers: NSUUID.
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, NSUUID *> *dataSource;
```

Declare the generic types on the property and on the snapshot. They are checked by the compiler only, but they make every block parameter readable.

## Identity anti-patterns

### The whole model as the identifier

Wrong:

```objc
@interface Message : NSObject            // mutable, and isEqual: / hash cover every field
@property (nonatomic, copy) NSUUID *messageID;
@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL read;
@end
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, Message *> *dataSource;
```

Marking a message read changes its hash, so the diff sees one item deleted and a different item inserted. The cell is thrown away and recreated, its state (selection, text selection, an in-flight image load, a swipe that was open) is lost, the change animates as a delete plus insert, and the scroll anchor can jump. The reverse also bites: a model class that does not override `isEqual:` and `hash` compares by pointer, so a freshly decoded copy of the same message is a different item.

Right: identify by ID and keep the model in a store.

```objc
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, NSUUID *> *dataSource;
@property (nonatomic, strong) NSMutableDictionary<NSUUID *, Message *> *store;
```

If you must keep a model class as the identifier (an existing codebase), make its `isEqual:` and `hash` use only the ID. Then reconfigure the item when other fields change, because the diff will not see those changes.

```objc
- (BOOL)isEqual:(id)object {
    if (self == object) { return YES; }
    if (![object isKindOfClass:[Message class]]) { return NO; }
    return [self.messageID isEqual:((Message *)object).messageID];
}
- (NSUInteger)hash { return self.messageID.hash; }
```

### Identifiers made up per snapshot

Wrong: a fresh `NSUUID` or an array index as the identifier.

```objc
NSMutableArray<NSUUID *> *ids = [NSMutableArray array];
for (Message *m in messages) { [ids addObject:[NSUUID UUID]]; }   // new identity every build
NSNumber *byIndex = @(idx);                                       // identity moves when anything is inserted
```

Every apply then looks like "everything replaced". Index-based identifiers are worse: inserting one item at the top shifts every identifier by one, so the diff reports a change in every row.

Right: an identifier that belongs to the item, assigned once.

### Content-derived identifiers

Wrong: an identifier built from the text (`@(text.hash)`, or the title string itself). Two items with the same text collide and crash; editing the text changes identity.

Right: content is looked up from the store by a stable ID. If items truly have no ID (rows parsed from a file), assign one when the data is loaded and keep it with the data.

### Duplicates

Server data and merged sources often repeat an item (a message that arrives over the socket and in the next page fetch). Remove duplicates before building the snapshot, keeping the first occurrence:

```objc
NSMutableOrderedSet<NSUUID *> *unique = [NSMutableOrderedSet orderedSet];
for (Message *m in incoming) { [unique addObject:m.messageID]; }   // a set ignores the second add
NSArray<NSUUID *> *ids = unique.array;
```

The same identifier can also not appear in two sections. If one model appears in two places (a "pinned" section and the main list), give each placement its own identifier: a small immutable class with a kind and an ID, with `isEqual:` and `hash` over both, or a string such as `[NSString stringWithFormat:@"pinned-%@", uuid.UUIDString]` built in one helper.

## Model storage

Keep the models outside the data source, keyed by ID: a dictionary, a database, or a model object. The cell registration handler receives an ID, looks up the model and configures the cell.

That gives two separate update paths:

| What changed | What to do |
|---|---|
| Which items exist, or their order | build a snapshot and apply it |
| Content of existing items | update the store, then reconfigure those IDs |

Because the snapshot holds only IDs, editing a field never rebuilds the list.

## Building and applying snapshots

```objc
NSDiffableDataSourceSnapshot<NSNumber *, NSUUID *> *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
[snapshot appendSectionsWithIdentifiers:@[@(MessageSectionPinned), @(MessageSectionRecent)]];
[snapshot appendItemsWithIdentifiers:pinnedIDs intoSectionWithIdentifier:@(MessageSectionPinned)];
[snapshot appendItemsWithIdentifiers:recentIDs intoSectionWithIdentifier:@(MessageSectionRecent)];
[self.dataSource applySnapshot:snapshot animatingDifferences:YES];
```

- Apply from one place, on the main thread. Two code paths that each build and apply their own snapshot race each other; funnel them through one method (`-applyMessagesAnimated:`).
- Build large snapshots from whole arrays (`appendItemsWithIdentifiers:` once per section), not item by item.
- Since iOS 15 `applySnapshot:animatingDifferences:NO` still diffs and keeps cells; it is not a reload. Use `-applySnapshotUsingReloadData:` only when you want to discard all cell state, such as after switching accounts.
- The completion variant, `-applySnapshot:animatingDifferences:completion:`, runs its block when the update has finished. Use it when the next step depends on the update (scrolling to a new item, restoring an anchor), and capture `weakSelf` in it.
- A snapshot is a copy-on-read object: `[dataSource snapshot]` returns a new one; edit that copy and apply it. Do not keep a snapshot in a property and mutate it later while also applying it.
- Animate changes the user caused (sending, deleting). Apply without animation when content changes far from the visible area, on first load, and during fast scrolling.

## Changing existing items

```objc
NSDiffableDataSourceSnapshot<NSNumber *, NSUUID *> *snapshot = [self.dataSource snapshot];
[snapshot reconfigureItemsWithIdentifiers:changedIDs];
[self.dataSource applySnapshot:snapshot animatingDifferences:YES];
```

- `-reconfigureItemsWithIdentifiers:` (iOS 15+) runs the registration's handler again on the existing cell. It is the cheap, correct way to show new content.
- `-reloadItemsWithIdentifiers:` dequeues a new cell. Use it only when an item must switch to a different cell type or registration.
- Only items that are in the snapshot can be reconfigured. Check `[snapshot indexOfItemIdentifier:id] != NSNotFound` before reconfiguring IDs that may have been removed; reconfiguring a missing identifier raises an exception. (`indexOfItemIdentifier:` returns `NSNotFound`, not `nil` or `-1`; `NSNotFound` is a large positive number, so `> 0` is a bug.)
- Never delete and reinsert an item to refresh it.

Wrong:

```objc
[snapshot deleteItemsWithIdentifiers:@[itemID]];
[snapshot insertItemsWithIdentifiers:@[itemID] afterItemWithIdentifier:previousID];
```

Right:

```objc
[snapshot reconfigureItemsWithIdentifiers:@[itemID]];
```

## Sections

- Section identifiers follow the same rules as item identifiers: stable, unique, small.
- `NSDiffableDataSourceSectionSnapshot<ItemIdentifierType>` represents one section, including a hierarchy for expandable outlines (`-appendItems:intoParentItem:`, `-expandItems:`, `-collapseItems:`). Apply it with `-applySnapshot:toSection:animatingDifferences:` to update one section without touching others.
- `dataSource.sectionSnapshotHandlers` reports expand and collapse (`shouldExpandItemHandler`, `willExpandItemHandler`, `shouldCollapseItemHandler`, `willCollapseItemHandler`), and `snapshotForExpandingParentItemHandler` can load children lazily when a parent expands.
- Mixing whole snapshots and section snapshots is allowed; the last apply wins for that section.

## Index paths and identifiers

Index paths describe positions in the current snapshot only. Identifiers describe items.

- Convert at the boundary: `-itemIdentifierForIndexPath:` when UIKit gives you an index path (delegate calls, swipe providers, context menus), and `-indexPathForItemIdentifier:` when you need to tell UIKit about an item. Both return `nil` for a position or item that is not there.
- Never store index paths for later (in a block, a menu action, a delayed call). Store the identifier and look up the index path when you act.

Wrong:

```objc
UIAction *action = [UIAction actionWithTitle:@"Delete" image:nil identifier:nil
                                     handler:^(UIAction *a) {
    [self deleteItemAtIndexPath:indexPath];     // the list may have changed by now, and self is retained
}];
```

Right:

```objc
NSUUID *itemID = [self.dataSource itemIdentifierForIndexPath:indexPath];
if (!itemID) { return nil; }
__weak typeof(self) weakSelf = self;
UIAction *action = [UIAction actionWithTitle:@"Delete" image:nil identifier:nil
                                     handler:^(__kindof UIAction *a) {
    [weakSelf deleteItem:itemID];
}];
```

## Reordering

With a diffable data source, enable reordering through `dataSource.reorderingHandlers`:

```objc
__weak typeof(self) weakSelf = self;
self.dataSource.reorderingHandlers.canReorderItemHandler = ^BOOL(NSUUID *itemID) { return YES; };
self.dataSource.reorderingHandlers.didReorderHandler =
    ^(NSDiffableDataSourceTransaction<NSNumber *, NSUUID *> *transaction) {
    [weakSelf.model applyOrder:transaction.finalSnapshot.itemIdentifiers];
};
```

The data source has already updated its own snapshot when `didReorderHandler` runs; update your model from `transaction.finalSnapshot` or `transaction.difference`. Do not apply a new snapshot from inside the handler. List cells show the reorder control with a `UICellAccessoryReorder` accessory.

`reorderingHandlers` is a copied property: assign a whole `UICollectionViewDiffableDataSourceReorderingHandlers` object, or set the handlers on the object you read back and write it back, rather than expecting a stored reference to update the data source.

## Building snapshots off the main thread

Diffing a snapshot of tens of thousands of items costs real time. Two options:

- Build the identifier arrays on a background queue (sorting, filtering, de-duplicating), then build and apply the snapshot on the main queue:

  ```objc
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      NSArray<NSUUID *> *ids = [self sortedUniqueIDs];
      dispatch_async(dispatch_get_main_queue(), ^{
          [self applyIDs:ids];
      });
  });
  ```

- Apply from a background queue. This is supported as long as every apply for that data source happens on the same serial queue; mixing queues is an error. Prefer the first option; it keeps all UIKit calls on the main thread.

## Diffable with table views

`UITableViewDiffableDataSource<SectionType, ItemType>` follows the same rules (`-initWithTableView:cellProvider:`). Its `defaultRowAnimation` sets the animation for inserts and deletes. Use `-reconfigureItemsWithIdentifiers:` on the snapshot to refresh rows.

## Review checks

1. Identifier type: an immutable ID object, not a mutable model, not an index, not content; `isEqual:` and `hash` agree.
2. Duplicates removed before every apply from merged sources.
3. One apply path, main thread.
4. Content changes go through reconfigure; reload only for a cell-type change.
5. No stored index paths; `NSNotFound` handled.
