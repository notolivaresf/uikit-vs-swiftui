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

```objc
configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *ip, NSUUID *postID) {
    Post *post = [Post postFromJSONData:self.rawStore[postID]];        // decoding per pass
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];       // new formatter per pass
    formatter.dateStyle = NSDateFormatterMediumStyle;
    UIListContentConfiguration *content = [cell defaultContentConfiguration];
    content.text = post.title;
    content.secondaryText = [formatter stringFromDate:post.date];
    content.image = [UIImage imageWithContentsOfFile:post.imagePath];   // disk read and decode on main
    cell.contentConfiguration = content;
}
```

(`self` inside the handler is also a strong capture.)

Right: models decoded once into the store, formatted strings cached or produced by cached formatters, images loaded asynchronously.

```objc
__weak typeof(self) weakSelf = self;
UICollectionViewCellRegistration *registration = [UICollectionViewCellRegistration
    registrationWithCellClass:[UICollectionViewListCell class]
         configurationHandler:^(UICollectionViewListCell *cell, NSIndexPath *ip, NSUUID *postID) {
    typeof(self) strongSelf = weakSelf;
    Post *post = strongSelf.store[postID];
    if (!post) { return; }
    UIListContentConfiguration *content = [cell defaultContentConfiguration];
    content.text = post.title;
    content.secondaryText = [strongSelf.dateFormatter stringFromDate:post.date];   // one formatter, made once
    content.image = [strongSelf.thumbnails cachedImageForURL:post.imageURL];       // memory cache only, may be nil
    cell.contentConfiguration = content;
    if (!content.image) { [strongSelf.thumbnails loadURL:post.imageURL forItemID:postID]; }  // reconfigure when it arrives
}];
```

When an image arrives for an item, reconfigure that identifier (or set the image on the visible cell after checking identity). Do not reload.

## Images

Decode and downscale before the image reaches an image view.

```objc
@interface ThumbnailLoader : NSObject
- (void)loadURL:(NSURL *)url pixelSize:(CGSize)size
     completion:(void (^)(UIImage * _Nullable image))completion;   // completion on the main queue
@end

@implementation ThumbnailLoader {
    NSCache<NSURL *, UIImage *> *_cache;
    NSURLSession *_session;
}

- (void)loadURL:(NSURL *)url pixelSize:(CGSize)size completion:(void (^)(UIImage *))completion {
    UIImage *cached = [_cache objectForKey:url];
    if (cached) { completion(cached); return; }
    NSURLSessionDataTask *task = [_session dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        [image prepareThumbnailOfSize:size completionHandler:^(UIImage * _Nullable thumbnail) {
            if (thumbnail) { [self->_cache setObject:thumbnail forKey:url]; }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(thumbnail); });
        }];
    }];
    [task resume];
}
@end
```

In the cell:

```objc
@implementation PhotoCell {
    NSUUID *_representedID;
}

- (void)showPhoto:(Photo *)photo loader:(ThumbnailLoader *)loader {
    _representedID = photo.photoID;
    self.imageView.image = nil;
    CGFloat scale = self.traitCollection.displayScale;
    CGSize pixels = CGSizeMake(CGRectGetWidth(self.bounds) * scale, CGRectGetHeight(self.bounds) * scale);
    NSUUID *requested = photo.photoID;
    __weak typeof(self) weakSelf = self;
    [loader loadURL:photo.url pixelSize:pixels completion:^(UIImage *image) {
        typeof(self) strongSelf = weakSelf;
        if (strongSelf && [strongSelf->_representedID isEqual:requested]) {
            strongSelf.imageView.image = image;
        }
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    _representedID = nil;
    self.imageView.image = nil;
}
@end
```

- `-prepareThumbnailOfSize:completionHandler:` decodes and scales in one step; `-prepareForDisplayWithCompletionHandler:` decodes at full size. Both run off the main thread and call back on an arbitrary queue, so hop to the main queue before touching UI. The synchronous forms (`-imageByPreparingThumbnailOfSize:`, `-imageByPreparingForDisplay`) are for background queues only.
- Thumbnail sizes are pixels: points times `traitCollection.displayScale`. Never use `[UIScreen mainScreen].scale`.
- For large files on disk, `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize` and `kCGImageSourceCreateThumbnailFromImageAlways` avoids loading the full image into memory. Release the `CFTypeRef`s you create (`CFRelease`, or `__bridge_transfer` into ARC).
- Cache the decoded, downscaled image, not the data. `NSCache` evicts under memory pressure; set `totalCostLimit` with pixel byte counts as the cost.
- Check that the cell still shows the same item before assigning; cells are reused while loads are in flight.
- SF Symbols and asset catalog images are already optimized; do not prepare them.

## Prefetching

Set `collectionView.prefetchDataSource` (a weak property: keep the object alive elsewhere) and implement `UICollectionViewDataSourcePrefetching`:

```objc
- (void)collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    for (NSIndexPath *indexPath in indexPaths) {
        NSUUID *itemID = [self.dataSource itemIdentifierForIndexPath:indexPath];
        Photo *photo = itemID ? self.store[itemID] : nil;
        if (photo) { [self.loader loadURL:photo.url pixelSize:self.thumbnailPixels completion:^(UIImage *image) {}]; }
    }
}

- (void)collectionView:(UICollectionView *)collectionView cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    // cancel the loads you started for these identifiers, if the loader supports it
}
```

- Prefetching is a hint; the cell must work when the image is not ready.
- It also drives paging: when index paths near the end are prefetched, request the next page.
- Cell prefetching (`isPrefetchingEnabled`, on by default) prepares cells before they are visible. Leave it on; it is why configuration must not depend on being on screen.

## Text

- Reuse formatters. `NSDateFormatter`, `NSNumberFormatter` and friends are expensive to create; keep one per format as a property or a `static` created in `dispatch_once`. Set `locale` and `timeZone` explicitly when output must not follow the user.
- Build attributed strings once per model change, not per configuration. Cache them keyed by ID and content size category.
- `UILabel` is cheaper than `UITextView` for display. Use a text view only for selection, custom link handling or editing (see `text.md`).
- For very long text in a cell, cap with `numberOfLines` and offer "more" instead of measuring thousands of lines.

## Layout cost

- Fewer views and constraints per cell is faster. One content configuration, or one stack, beats many nested stacks in a cell shown hundreds of times.
- Change constraint constants, not constraints, and never in `layoutSubviews`.
- Activate constraints in batches with `+[NSLayoutConstraint activateConstraints:]`.
- An ambiguous layout is slow: the engine works harder and results can change between passes. Fix every unsatisfiable-constraints log.
- Do not call `layoutIfNeeded` in loops or on the whole window to "fix" layout.
- Do not measure cells by hand with `systemLayoutSizeFittingSize:` on a sizing cell; let self-sizing measure.

## Rendering

- Rounded corners: `layer.cornerRadius` with `layer.cornerCurve = kCACornerCurveContinuous` is cheap alone. Adding `masksToBounds = YES` over changing content forces an offscreen pass; round only the image view, or use a background configuration's corner radius.
- Shadows: set `layer.shadowPath` and update it in `layoutSubviews`, or the shadow is computed from the layer's alpha every frame.
- `shouldRasterize` helps only for complex, static content drawn at one size. On changing cells it costs more than it saves. Measure first.
- `alpha < 1` on a container with many subviews causes group opacity; fade the specific subviews or use colors with alpha.
- Blur and glass effect views are expensive; do not put one in every cell.
- Draw with `UIGraphicsImageRenderer`, never `UIGraphicsBeginImageContextWithOptions` (deprecated). Cache the rendered image.

## Frame callbacks

- Prefer `+[UIView animateWithDuration:...]`, `UIViewPropertyAnimator` and springs; they run in the render server and survive main-thread stalls better than per-frame code.
- For work tied to display refresh, use `UIUpdateLink` (iOS 18+), created with `+updateLinkForView:` or `+updateLinkForWindowScene:`; it follows the display's rate and pauses when the view is not visible. `CADisplayLink` remains for older targets: it retains its target, so give it a weak proxy or invalidate it in `viewDidDisappear:`, or the controller never deallocates.
- `NSTimer` scheduled on the default run loop mode stops during scrolling. Add it to `NSRunLoopCommonModes`, or use `dispatch_after` for delays. `+scheduledTimerWithTimeInterval:repeats:block:` with `weakSelf` avoids the target retain cycle of the selector form.

## Measuring

Measure on a device with a Release build. The simulator and Debug builds mislead.

- **Animation Hitches** template: each hitch, its duration, and whether commit or render was late. Start here for janky scrolling.
- **Time Profiler**: what the main thread does. Filter to the main thread, invert the call tree, hide system libraries.
- **Allocations** and **Leaks**: growth while scrolling back and forth over the same content means a cache or reuse bug. Retain cycles through blocks show up here as controllers that never deallocate.
- `os_signpost` intervals (`os_signpost_interval_begin` and `_end` on an `os_log_t`) around your own phases so they appear next to system tracks.

Automate with XCTest:

```objc
- (void)testScrollHitches {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];
    XCUIElement *list = app.collectionViews.firstMatch;
    [self measureWithMetrics:@[XCTOSSignpostMetric.scrollingAndDecelerationMetric]
                       block:^{ [list swipeUpWithVelocity:XCUIGestureVelocityFast]; }];
}
```

This reports hitch time ratio and frame rate while scrolling (`scrollingAndDecelerationMetric` is a class property; the older `scrollDecelerationMetric` is deprecated). Keep the device and data set fixed between runs and compare medians.

Also check the Xcode Organizer's hang and scroll-hitch metrics for field data, the Main Thread Checker for UIKit calls off main, and `-UIViewLayoutFeedbackLoopDebuggingThreshold` when layout loops.

## Review checks

1. Configuration handlers only look up and assign, and capture `weakSelf`.
2. Images decoded and downscaled off main, cached decoded, identity checked on arrival, UI set on the main queue.
3. Formatters and attributed strings reused.
4. Shadows have paths; no masks over changing content; no blur per cell.
5. A hitch test or Instruments trace backs every performance claim.
