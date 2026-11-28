#import <AppKit/AppKit.h>

@interface Fixture : NSObject <NSApplicationDelegate>
@end
@implementation Fixture {
    NSWindow *_window;
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(200, 200, 320, 120)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    _window.title = @"GLM Tray integration fixture";
    [_window orderFront:nil];
}
@end
int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        __attribute__((objc_precise_lifetime)) Fixture *delegate = [Fixture new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
