#import <AppKit/AppKit.h>

@interface GLMController : NSObject
@property(nonatomic, readonly) NSURL *selectedURL;
@property(nonatomic, readonly) NSRunningApplication *target;
@property(nonatomic) BOOL automaticallyHide;

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults delay:(NSTimeInterval)delay;
- (BOOL)selectApplication:(NSURL *)url;
- (NSURL *)validatedLaunchURL;
- (BOOL)showTarget;
- (BOOL)hideTarget;
- (void)stop;
@end
