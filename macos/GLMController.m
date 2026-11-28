#import "GLMController.h"

static NSURL *Canonical(NSURL *url) {
    return url.URLByStandardizingPath.URLByResolvingSymlinksInPath;
}

static BOOL LooksLikeGLM(NSBundle *bundle) {
    if (!bundle.bundleIdentifier.length ||
        [bundle.bundleIdentifier isEqualToString:@"org.qingaudio.GLMTray"] ||
        ![bundle.bundleURL.pathExtension.lowercaseString isEqualToString:@"app"] ||
        ![[NSFileManager defaultManager] isExecutableFileAtPath:bundle.executablePath]) return NO;
    NSArray *names = @[bundle.executableURL.lastPathComponent ?: @"",
                       [bundle objectForInfoDictionaryKey:@"CFBundleName"] ?: @"",
                       [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"",
                       bundle.bundleURL.lastPathComponent.stringByDeletingPathExtension ?: @""];
    for (NSString *name in names) {
        NSString *s = name.lowercaseString;
        if ([s containsString:@"genelec loudspeaker manager"] ||
            [s rangeOfString:@"^(genelec[ ._-]*)?glm([ ._-]*v?[0-9]+([._-][0-9]+)*)?$"
                     options:NSRegularExpressionSearch].location != NSNotFound) return YES;
    }
    return NO;
}

@implementation GLMController {
    NSUserDefaults *_defaults;
    NSString *_bundleID;
    NSURL *_selectedURL;
    NSRunningApplication *_target;
    NSTimeInterval _delay;
    NSTimer *_timer;
    BOOL _waitingForSwitch;
    BOOL _hidTarget;
}
@synthesize selectedURL = _selectedURL, target = _target;

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults delay:(NSTimeInterval)delay {
    if ((self = [super init])) {
        _defaults = defaults;
        _delay = delay;
        [_defaults registerDefaults:@{@"AutoHide": @YES}];
        NSDictionary *selection = [_defaults dictionaryForKey:@"GLMSelection"];
        if ([selection[@"path"] isKindOfClass:NSString.class] && [selection[@"id"] isKindOfClass:NSString.class]) {
            _selectedURL = Canonical([NSURL fileURLWithPath:selection[@"path"] isDirectory:YES]);
            _bundleID = [selection[@"id"] copy];
        }
        NSNotificationCenter *center = NSWorkspace.sharedWorkspace.notificationCenter;
        [center addObserver:self selector:@selector(launched:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
        [center addObserver:self selector:@selector(terminated:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
        [center addObserver:self selector:@selector(activated:) name:NSWorkspaceDidActivateApplicationNotification object:nil];
        [center addObserver:self selector:@selector(unhidden:) name:NSWorkspaceDidUnhideApplicationNotification object:nil];
        [self attachIfRunning];
    }
    return self;
}

- (BOOL)matches:(NSRunningApplication *)app {
    return app && !app.terminated && [_bundleID isEqualToString:app.bundleIdentifier] &&
           [_selectedURL isEqual:Canonical(app.bundleURL)];
}

- (void)cancelPending {
    [_timer invalidate];
    _timer = nil;
    _waitingForSwitch = NO;
}

- (void)restoreOwnedHide {
    [self cancelPending];
    if (_hidTarget && _target.hidden && !_target.terminated) [_target unhide];
    _hidTarget = NO;
}

- (void)hideWhenInBackground {
    if (!_waitingForSwitch || !_target || _target.terminated) return;
    if (_target.active || [NSWorkspace.sharedWorkspace.frontmostApplication isEqual:_target]) return;
    _waitingForSwitch = NO;
    [self hideTarget];
}

- (void)timerFired:(NSTimer *)sender {
    if (sender != _timer) return;
    _timer = nil;
    _waitingForSwitch = YES;
    [self hideWhenInBackground];
}

- (void)scheduleAutomaticHide {
    [self cancelPending];
    if (!self.automaticallyHide || !_target || _target.hidden || _target.terminated) return;
    _timer = [NSTimer timerWithTimeInterval:_delay target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)attach:(NSRunningApplication *)app {
    if (![self matches:app] || [_target isEqual:app]) return;
    [self restoreOwnedHide];
    _target = app;
    [self scheduleAutomaticHide];
}

- (void)attachIfRunning {
    if (!_bundleID.length) return;
    for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:_bundleID]) {
        if ([self matches:app]) { [self attach:app]; return; }
    }
}

- (BOOL)selectApplication:(NSURL *)url {
    NSURL *location = Canonical(url);
    NSBundle *bundle = location ? [NSBundle bundleWithURL:location] : nil;
    if (!LooksLikeGLM(bundle)) return NO;
    [self restoreOwnedHide];
    _target = nil;
    _bundleID = [bundle.bundleIdentifier copy];
    _selectedURL = location;
    [_defaults setObject:@{@"path": location.path, @"id": _bundleID} forKey:@"GLMSelection"];
    [self attachIfRunning];
    return YES;
}

- (BOOL)automaticallyHide { return [_defaults boolForKey:@"AutoHide"]; }
- (NSURL *)validatedLaunchURL {
    if (!_selectedURL) return nil;
    NSBundle *bundle = [NSBundle bundleWithURL:_selectedURL];
    return LooksLikeGLM(bundle) && [_bundleID isEqualToString:bundle.bundleIdentifier] ? _selectedURL : nil;
}
- (void)setAutomaticallyHide:(BOOL)value {
    [_defaults setBool:value forKey:@"AutoHide"];
    [self scheduleAutomaticHide];
}

- (void)launched:(NSNotification *)note { [self attach:note.userInfo[NSWorkspaceApplicationKey]]; }
- (void)terminated:(NSNotification *)note {
    if (![_target isEqual:note.userInfo[NSWorkspaceApplicationKey]]) return;
    [self cancelPending];
    _hidTarget = NO;
    _target = nil;
    [self attachIfRunning];
}
- (void)activated:(NSNotification *)note {
    if (_waitingForSwitch && ![_target isEqual:note.userInfo[NSWorkspaceApplicationKey]]) [self hideWhenInBackground];
}
- (void)unhidden:(NSNotification *)note {
    if (![_target isEqual:note.userInfo[NSWorkspaceApplicationKey]]) return;
    [self cancelPending];
    _hidTarget = NO;
}

- (BOOL)hideTarget {
    [self cancelPending];
    if (!_target || _target.terminated) return NO;
    if (_target.hidden) return YES;
    if (![_target hide]) return NO;
    _hidTarget = YES;
    return YES;
}

- (BOOL)showTarget {
    [self cancelPending];
    if (!_target || _target.terminated) return NO;
    if (_target.hidden && ![_target unhide]) return NO;
    _hidTarget = NO;
    // A menu-bar agent can cooperate with the target for activation on Sonoma and later.
    if (@available(macOS 14.0, *)) {
        [NSApp yieldActivationToApplication:_target];
        [_target activateWithOptions:NSApplicationActivateAllWindows];
    } else {
        [_target activateWithOptions:NSApplicationActivateIgnoringOtherApps | NSApplicationActivateAllWindows];
    }
    return YES;
}

- (void)stop {
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [self restoreOwnedHide];
    _target = nil;
}
@end
