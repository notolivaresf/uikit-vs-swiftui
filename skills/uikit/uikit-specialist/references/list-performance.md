# List and rendering performance

Each frame the main thread has a few milliseconds (about 8 ms at 120 Hz, 16 ms at 60 Hz) to run your code, lay out and commit. Anything that does not have to happen on the main thread, or does not have to happen now, should not happen there.

## Where time goes in a scrolling list

1. Cell configuration (the registration handler). It must be a lookup plus property sets.
2. Auto Layout for self-sizing cells. Cost grows with constraint count and ambiguity.
3. Text layout. Long attributed strings are measured each time a cell is sized.
4. Image decoding. A compressed image is decoded the first time it is drawn, on the main thread, unless decoded earlier.
5. Rendering: offscreen passes from masks, shadows without paths, group opacity and blur.

## Cell configuration budget

Wrong: work in the handler.

```swift
let registration = UICollectionView.CellRegistration<UICollectionViewListCell, PostID> { cell, _, id in
    let post = try! JSONDecoder().decode(Post.self, from: self.rawStore[id]!)   // decoding per pass
    let formatter = DateFormatter()                                             // new formatter per pass
    formatter.dateStyle = .medium
    var content = cell.defaultContentConfiguration()
    content.text = post.title
    content.secondaryText = formatter.string(from: post.date)
    content.image = UIImage(contentsOfFile: post.imagePath)                     // disk read and decode on main
    cell.contentConfiguration = content
}
```

Right: models decoded once into the store, formatted strings cached or produced by cached formatters, images loaded asynchronously.

```swift
let registration = UICollectionView.CellRegistration<UICollectionViewListCell, PostID> { [weak self] cell, _, id in
    guard let self, let post = self.store[id] else { return }
    var content = cell.defaultContentConfiguration()
    content.text = post.title
    content.secondaryText = post.date.formatted(date: .abbreviated, time: .omitted)
    content.image = self.thumbnails.cachedImage(for: post.imageURL)        // memory cache only, may be nil
    cell.contentConfiguration = content
    if content.image == nil { self.thumbnails.load(post.imageURL, for: id) }  // reconfigure id when it arrives
}
```

When an image arrives for an item, reconfigure that identifier (or set the image on the visible cell after checking identity). Do not reload.

## Images

Decode and downscale before the image reaches an image view.

```swift
actor ThumbnailLoader {
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL, pixelSize: CGSize) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let task = inFlight[url] { return await task.value }
        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return nil }
            return await image.byPreparingThumbnail(ofSize: pixelSize)
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result { cache.setObject(result, forKey: url as NSURL) }
        return result
    }
}
```

In the cell:

```swift
final class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()
    private var loadTask: Task<Void, Never>?
    private var representedID: PhotoID?

    func show(_ photo: Photo, loader: ThumbnailLoader) {
        representedID = photo.id
        imageView.image = nil
        loadTask?.cancel()
        let scale = traitCollection.displayScale
        let pixels = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        loadTask = Task { [weak self] in
            let image = await loader.image(for: photo.url, pixelSize: pixels)
            guard let self, !Task.isCancelled, self.representedID == photo.id else { return }
            self.imageView.image = image
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        imageView.image = nil
    }
}
```

- `byPreparingThumbnail(ofSize:)` decodes and scales in one step; `byPreparingForDisplay()` decodes at full size. Both are async and run off the main thread. Completion-handler forms (`prepareThumbnail(of:completionHandler:)`, `prepareForDisplay(completionHandler:)`) and synchronous forms (`preparingThumbnail(of:)`, `preparingForDisplay()`) exist for background queues.
- Thumbnail sizes are pixels: points times `traitCollection.displayScale`. Never use `UIScreen.main.scale`.
- For large files on disk, `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize` and `kCGImageSourceCreateThumbnailFromImageAlways` avoids loading the full image into memory.
- Cache the decoded, downscaled image, not the data. `NSCache` evicts under memory pressure; set `totalCostLimit` with pixel byte counts as the cost.
- Check that the cell still shows the same item before assigning; cells are reused while loads are in flight.
- SF Symbols and asset catalog images are already optimized; do not prepare them.

## Prefetching

Set `collectionView.prefetchDataSource` and implement `UICollectionViewDataSourcePrefetching`:

```swift
func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
        guard let id = dataSource.itemIdentifier(for: indexPath), let photo = store[id] else { continue }
        prefetchTasks[id] = Task { _ = await loader.image(for: photo.url, pixelSize: thumbnailPixels) }
    }
}

func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    for indexPath in indexPaths {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { continue }
        prefetchTasks.removeValue(forKey: id)?.cancel()
    }
}
```

- Prefetching is a hint; the cell must work when the image is not ready.
- It also drives paging: when index paths near the end are prefetched, request the next page.
- Cell prefetching (`isPrefetchingEnabled`, on by default) prepares cells before they are visible. Leave it on; it is why configuration must not depend on being on screen.

## Text

- Reuse formatters. `DateFormatter`, `NumberFormatter` and friends are expensive to create; keep one per format, or use the `formatted()` APIs, which cache.
- Build attributed strings once per model change, not per configuration. Cache them keyed by ID and content size category.
- `UILabel` is cheaper than `UITextView` for display. Use a text view only for selection, custom link handling or editing (see `text.md`).
- For very long text in a cell, cap with `numberOfLines` and offer "more" instead of measuring thousands of lines.

## Layout cost

- Fewer views and constraints per cell is faster. One content configuration, or one stack, beats many nested stacks in a cell shown hundreds of times.
- Change constraint constants, not constraints, and never in `layoutSubviews`.
- Activate constraints in batches with `NSLayoutConstraint.activate(_:)`.
- An ambiguous layout is slow: the engine works harder and results can change between passes. Fix every unsatisfiable-constraints log.
- Do not call `layoutIfNeeded()` in loops or on the whole window to "fix" layout.
- Do not measure cells by hand with `systemLayoutSizeFitting` on a sizing cell; let self-sizing measure.

## Rendering

- Rounded corners: `layer.cornerRadius` with `cornerCurve = .continuous` is cheap alone. Adding `masksToBounds = true` over changing content forces an offscreen pass; round only the image view, or use a background configuration's corner radius.
- Shadows: set `layer.shadowPath` and update it in `layoutSubviews`, or the shadow is computed from the layer's alpha every frame.
- `shouldRasterize` helps only for complex, static content drawn at one size. On changing cells it costs more than it saves. Measure first.
- `alpha < 1` on a container with many subviews causes group opacity; fade the specific subviews or use colors with alpha.
- Blur and glass effect views are expensive; do not put one in every cell.
- Draw with `UIGraphicsImageRenderer`, never `UIGraphicsBeginImageContextWithOptions` (deprecated). Cache the rendered image.

## Frame callbacks

- Prefer `UIView.animate`, `UIViewPropertyAnimator` and springs; they run in the render server and survive main-thread stalls better than per-frame code.
- For work tied to display refresh, use `UIUpdateLink` (iOS 18+), created for a view or a window scene; it follows the display's rate and pauses when the view is not visible. `CADisplayLink` remains for older targets.
- `Timer` on the default run loop mode stops during scrolling. Add it in `.common` mode, or use a `Task` with `Task.sleep(for:)` for delays.

## Measuring

Measure on a device with a Release build. The simulator and Debug builds mislead.

- **Animation Hitches** template: each hitch, its duration, and whether commit or render was late. Start here for janky scrolling.
- **Time Profiler**: what the main thread does. Filter to the main thread, invert the call tree, hide system libraries.
- **Allocations** and **Leaks**: growth while scrolling back and forth over the same content means a cache or reuse bug.
- **Swift Concurrency**: tasks and actor hops, for work you expected off main.
- `OSSignposter` intervals around your own phases so they appear next to system tracks.

Automate with XCTest:

```swift
func testScrollHitches() {
    let app = XCUIApplication()
    app.launch()
    let list = app.collectionViews.firstMatch
    measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
        list.swipeUp(velocity: .fast)
    }
}
```

This reports hitch time ratio and frame rate while scrolling. Keep the device and data set fixed between runs and compare medians.

Also check the Xcode Organizer's hang and scroll-hitch metrics for field data, the Main Thread Checker for UIKit calls off main, and `-UIViewLayoutFeedbackLoopDebuggingThreshold` when layout loops.

## Review checks

1. Configuration handlers only look up and assign.
2. Images decoded and downscaled off main, cached decoded, identity checked on arrival.
3. Formatters and attributed strings reused.
4. Shadows have paths; no masks over changing content; no blur per cell.
5. A hitch test or Instruments trace backs every performance claim.
