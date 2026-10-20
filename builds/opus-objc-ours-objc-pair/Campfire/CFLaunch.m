#import "CFLaunch.h"

NSTimeInterval CFLaunchStart = 0;
static CFKDataset *sDataset;
static dispatch_group_t sGroup;

void CFLaunchBeginLoadingDataset(void) {
    sGroup = dispatch_group_create();
    dispatch_group_async(sGroup, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        CFKDataset *d = [[CFKDataset alloc] init];
        (void)d.users;
        sDataset = d;
    });
}

CFKDataset *CFLaunchDataset(void) {
    if (!sGroup) { CFLaunchBeginLoadingDataset(); }
    dispatch_group_wait(sGroup, DISPATCH_TIME_FOREVER);
    return sDataset;
}
