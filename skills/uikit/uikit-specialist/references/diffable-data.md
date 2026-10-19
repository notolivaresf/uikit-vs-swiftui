# Diffable data sources and item identity

A diffable data source shows a snapshot: an ordered list of section identifiers and item identifiers. When you apply a new snapshot, UIKit compares it with the old one by identity and animates the inserts, deletes and moves. Everything in this file follows from that: the identifier is the item's identity, and identity decides animation, cell reuse, selection, scroll anchoring and performance.

## What makes a good identifier

An item identifier must be:

- **Stable**: the same item has the same identifier across every snapshot, for as long as it exists.
- **Unique**: no two items in one snapshot share it. Duplicates raise an exception when the snapshot is applied.
- **Small and cheap to hash**: the diff hashes every identifier on each apply.
- **Sendable** in Swift 6 code, since snapshots are often built off the main actor.

The best identifier is the model's own ID: a database key, a server ID, a `UUID` assigned once when the model is created.

```swift
enum Section: Hashable, Sendable { case pinned, recent }
struct MessageID: Hashable, Sendable { let rawValue: UUID }

var dataSource: UICollectionViewDiffableDataSource<Section, MessageID>!
```

## Identity anti-patterns

### The whole model as the identifier

Wrong:

```swift
struct Message: Hashable { let id: UUID; var text: String; var isRead: Bool }
var dataSource: UICollectionViewDiffableDataSource<Section, Message>!
```

Marking a message read changes its hash, so the diff sees one item deleted and a different item inserted. The cell is thrown away and recreated, its state (selection, text selection, an in-flight image load, a swipe that was open) is lost, the change animates as a delete plus insert, and the scroll anchor can jump.

Right: identify by ID and keep the model in a store.

```swift
var dataSource: UICollectionViewDiffableDataSource<Section, MessageID>!
var store: [MessageID: Message] = [:]
```

If you must keep a model type as the identifier (an existing codebase), make its `Hashable` and `==` use only the ID. Then reconfigure the item when other fields change, because the diff will not see those changes.

### Identifiers made up per snapshot

Wrong: a fresh `UUID()` or an array index as the identifier.

```swift
let ids = messages.map { _ in UUID() }            // new identity every build
let ids = messages.indices.map { ItemID(index: $0) }   // identity moves when anything is inserted
```

Every apply then looks like "everything replaced". Index-based identifiers are worse: inserting one item at the top shifts every identifier by one, so the diff reports a change in every row.

Right: an identifier that belongs to the item, assigned once.

### Content-derived identifiers

Wrong: an identifier built from the text (`ItemID(text.hashValue)`) or from a title. Two items with the same text collide and crash; editing the text changes identity.

Right: content is looked up from the store by a stable ID. If items truly have no ID (rows parsed from a file), assign one when the data is loaded and keep it with the data.

### Duplicates

Server data and merged sources often repeat an item (a message that arrives over the socket and in the next page fetch). Remove duplicates before building the snapshot, keeping the first occurrence:

```swift
var seen = Set<MessageID>()
let unique = incoming.filter { seen.insert($0.id).inserted }
```

The same identifier can also not appear in two sections. If one model appears in two places (a "pinned" section and the main list), give each placement its own identifier, for example an enum with associated values:

```swift
enum Row: Hashable, Sendable {
    case pinned(MessageID)
    case message(MessageID)
}
```

## Model storage

Keep the models outside the data source, keyed by ID: a dictionary, a database, or an observable model object. The cell registration handler receives an ID, looks up the model and configures the cell.

That gives two separate update paths:

| What changed | What to do |
|---|---|
| Which items exist, or their order | build a snapshot and apply it |
| Content of existing items | update the store, then reconfigure those IDs |

Because the snapshot holds only IDs, editing a field never rebuilds the list.

## Building and applying snapshots

```swift
var snapshot = NSDiffableDataSourceSnapshot<Section, MessageID>()
snapshot.appendSections([.pinned, .recent])
snapshot.appendItems(pinnedIDs, toSection: .pinned)
snapshot.appendItems(recentIDs, toSection: .recent)
dataSource.apply(snapshot, animatingDifferences: true)
```

- Apply from one place, on the main actor. Two code paths that each build and apply their own snapshot race each other; funnel them through one method.
- Build large snapshots from whole arrays (`appendItems(_:)` once per section), not item by item.
- Since iOS 15 `apply(_:animatingDifferences: false)` still diffs and keeps cells; it is not a reload. Use `applySnapshotUsingReloadData(_:)` only when you want to discard all cell state, such as after switching accounts.
- `apply` has an async form. Await it when the next step depends on the update having finished (scrolling to a new item, restoring an anchor).
- The snapshot type is a value. `dataSource.snapshot()` returns a copy; edit the copy and apply it.
- Animate changes the user caused (sending, deleting). Apply without animation when content changes far from the visible area, on first load, and during fast scrolling.

## Changing existing items

```swift
var snapshot = dataSource.snapshot()
snapshot.reconfigureItems(changedIDs)
dataSource.apply(snapshot, animatingDifferences: true)
```

- `reconfigureItems(_:)` (iOS 15+) runs the registration's handler again on the existing cell. It is the cheap, correct way to show new content.
- `reloadItems(_:)` dequeues a new cell. Use it only when an item must switch to a different cell type or registration.
- Only items that are in the snapshot can be reconfigured. Check `snapshot.indexOfItem(_:) != nil` before reconfiguring IDs that may have been removed; reconfiguring a missing identifier raises an exception.
- Never delete and reinsert an item to refresh it.

Wrong:

```swift
snapshot.deleteItems([id])
snapshot.insertItems([id], afterItem: previous)
```

Right:

```swift
snapshot.reconfigureItems([id])
```

## Sections

- Section identifiers follow the same rules as item identifiers: stable, unique, small.
- `NSDiffableDataSourceSectionSnapshot` represents one section, including a hierarchy for expandable outlines (`append(_:to:)`, `expand(_:)`, `collapse(_:)`). Apply it with `dataSource.apply(_:to:animatingDifferences:)` to update one section without touching others.
- `dataSource.sectionSnapshotHandlers` reports expand and collapse, and can load children lazily when a parent expands.
- Mixing whole snapshots and section snapshots is allowed; the last apply wins for that section.

## Index paths and identifiers

Index paths describe positions in the current snapshot only. Identifiers describe items.

- Convert at the boundary: `dataSource.itemIdentifier(for: indexPath)` when UIKit gives you an index path (delegate calls, swipe providers, context menus), and `dataSource.indexPath(for: id)` when you need to tell UIKit about an item.
- Never store index paths for later (in a closure, a menu action, a task). Store the identifier and look up the index path when you act.

Wrong:

```swift
let action = UIAction(title: "Delete") { _ in
    self.deleteItem(at: indexPath)        // the list may have changed by now
}
```

Right:

```swift
guard let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
let action = UIAction(title: "Delete") { [weak self] _ in
    self?.deleteItem(id)
}
```

## Reordering

With a diffable data source, enable reordering through `dataSource.reorderingHandlers`:

```swift
dataSource.reorderingHandlers.canReorderItem = { _ in true }
dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
    self?.model.applyOrder(transaction.finalSnapshot.itemIdentifiers)
}
```

The data source has already updated its own snapshot when `didReorder` runs; update your model from `transaction.finalSnapshot` or `transaction.difference`. Do not apply a new snapshot from inside the handler. List cells show the reorder control with the `.reorder()` accessory.

## Building snapshots off the main actor

Diffing a snapshot of tens of thousands of items costs real time. Two options:

- Build the identifier arrays on a background actor (sorting, filtering, de-duplicating), then build and apply the snapshot on the main actor.
- Apply from a background queue. This is supported as long as every apply for that data source happens on the same queue; mixing queues is an error. In Swift 6 code, prefer the first option; it keeps all UIKit calls on the main actor.

## Diffable with table views

`UITableViewDiffableDataSource` follows the same rules. Its `defaultRowAnimation` sets the animation for inserts and deletes. Use `reconfigureItems(_:)` on the snapshot to refresh rows.

## Review checks

1. Identifier type: an ID, not a mutable model, not an index, not content.
2. Duplicates removed before every apply from merged sources.
3. One apply path, main actor.
4. Content changes go through reconfigure; reload only for a cell-type change.
5. No stored index paths.
