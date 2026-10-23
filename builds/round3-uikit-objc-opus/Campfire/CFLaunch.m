#import "CFLaunch.h"
#import "CFRoomStore.h"
#import "CFRowLayout.h"

NSTimeInterval CFLaunchStart = 0;
CGFloat CFLaunchScreenScale = 0;
static CFRoomStore *sStore;
static NSArray<CFMessageItem *> *sInitialItems;
static dispatch_group_t sGroup;

static NSString *const kGeometryKey = @"CFLaunchGeometry";

void CFLaunchBegin(void) {
    sGroup = dispatch_group_create();
    dispatch_group_async(sGroup, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSDictionary *geometry = [NSUserDefaults.standardUserDefaults dictionaryForKey:kGeometryKey];
        CGFloat width = [geometry[@"width"] doubleValue];
        NSString *category = geometry[@"category"];
        CGFloat scale = [geometry[@"scale"] doubleValue];
        CFKDataset *d = [[CFKDataset alloc] init];
        CFRoomStore *store = [[CFRoomStore alloc] initWithDataset:d];
        NSArray<CFMessageItem *> *items = [store newestItems:CFKDataset.pageSize];
        if (width > 0 && scale > 0 && [category isKindOfClass:[NSString class]]) {
            CFLaunchScreenScale = scale;
            CFMetrics *m = [CFMetrics metricsForCategory:category];
            for (CFMessageItem *item in items) {
                item.layout = [CFRowLayout layoutForItem:item store:store width:width metrics:m];
            }
        }
        sStore = store;
        sInitialItems = items;
    });
}

void CFLaunchRememberGeometry(CGFloat width, UIContentSizeCategory category, CGFloat scale) {
    CFLaunchScreenScale = scale;
    NSDictionary *geometry = @{@"width": @(width), @"category": category ?: UIContentSizeCategoryLarge, @"scale": @(scale)};
    if (![[NSUserDefaults.standardUserDefaults dictionaryForKey:kGeometryKey] isEqualToDictionary:geometry]) {
        [NSUserDefaults.standardUserDefaults setObject:geometry forKey:kGeometryKey];
    }
}

static void CFLaunchWait(void) {
    if (!sGroup) { CFLaunchBegin(); }
    dispatch_group_wait(sGroup, DISPATCH_TIME_FOREVER);
}

CFRoomStore *CFLaunchStore(void) { CFLaunchWait(); return sStore; }
NSArray<CFMessageItem *> *CFLaunchInitialItems(void) { CFLaunchWait(); return sInitialItems; }
