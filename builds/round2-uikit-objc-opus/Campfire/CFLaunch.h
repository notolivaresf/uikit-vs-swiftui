@import Foundation;
@import CampfireKitObjC;

NS_ASSUME_NONNULL_BEGIN

/// System uptime at the first line of `main`, for the launch time in the debug bar.
extern NSTimeInterval CFLaunchStart;
/// Starts generating the 50,000-message dataset on a background queue, in parallel with UIKit's launch.
void CFLaunchBeginLoadingDataset(void);
/// The dataset; waits for generation to finish if needed.
CFKDataset *CFLaunchDataset(void);

NS_ASSUME_NONNULL_END
