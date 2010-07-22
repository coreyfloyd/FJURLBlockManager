
#import <UIKit/UIKit.h>

@class NetworkDemoViewController;

@interface NetworkDemoAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    NetworkDemoViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet NetworkDemoViewController *viewController;

@end

