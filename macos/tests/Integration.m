#import <AppKit/AppKit.h>
#import <libproc.h>
#import <sys/resource.h>
#import "../GLMController.h"

static NSMutableArray<NSString *> *checks;
static void Check(BOOL ok, NSString *name) {
    if (!ok) { fprintf(stderr, "FAILED: %s\n", name.UTF8String); exit(1); }
    [checks addObject:name]; printf("PASS %s\n", name.UTF8String); fflush(stdout);
}

static BOOL Wait(NSTimeInterval timeout, BOOL (^check)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.04]];
        if (check()) return YES;
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static void Spin(NSTimeInterval duration) { [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:duration]]; }
static NSRunningApplication *Open(NSURL *url, BOOL activate) {
    __block NSRunningApplication *result = nil;
    __block BOOL finished = NO;
    NSWorkspaceOpenConfiguration *cfg = NSWorkspaceOpenConfiguration.configuration;
    cfg.activates = activate;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:cfg completionHandler:^(NSRunningApplication *app, NSError *err) {
        if (err) NSLog(@"Open %@: %@", url, err);
        dispatch_async(dispatch_get_main_queue(), ^{ result = app; finished = YES; });
    }];
    if (!Wait(12, ^BOOL{ return finished && (result == nil || result.finishedLaunching); })) return nil;
    return result;
}

static void End(NSRunningApplication *app) {
    [app terminate];
    Check(Wait(12, ^BOOL{ return app.terminated; }), @"App exited normally");
}

static uint64_t CPU(pid_t pid) {
    struct rusage_info_v2 ru = {0};
    if (proc_pid_rusage(pid, RUSAGE_INFO_V2, (rusage_info_t *)&ru) < 0) { perror("proc_pid_rusage"); exit(2); }
    return ru.ri_user_time + ru.ri_system_time;
}

static NSDictionary *MeasureIdle(pid_t pid) {
    const NSUInteger n = NSProcessInfo.processInfo.activeProcessorCount;
    Spin(3);
    uint64_t initial = CPU(pid), last = initial;
    NSTimeInterval start = NSProcessInfo.processInfo.systemUptime, prior = start, now = start;
    double peak = 0;
    NSUInteger over = 0;
    for (NSUInteger i = 0; i < 120; i++) {
        Spin(1);
        uint64_t cpu = CPU(pid);
        now = NSProcessInfo.processInfo.systemUptime;
        double pct = 100.0 * (cpu-last) / (1.0e9 * (now-prior) * n);
        peak = MAX(peak, pct);
        if (pct > 0.05) over++;
        prior = now; last = cpu;
    }
    return @{@"seconds": @(now-start), @"samples": @120, @"logicalCPUs": @(n),
             @"meanPercent": @(100.0 * (last-initial) / (1.0e9 * (now-start) * n)),
             @"maxPercent": @(peak), @"samplesAbove005": @(over)};
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc != 4) return 2;
        [NSApplication sharedApplication];
        checks = [NSMutableArray new];
        NSURL *fixture = [NSURL fileURLWithPath:@(argv[1]) isDirectory:YES];
        NSURL *helper = [NSURL fileURLWithPath:@(argv[2]) isDirectory:YES];
        NSString *domain = @"org.qingaudio.GLMTray.TestPreferences";
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:domain];
        [prefs removePersistentDomainForName:domain];
        GLMController *c = [[GLMController alloc] initWithDefaults:prefs delay:0.6];
        Check(![c selectApplication:helper], @"Refuses to target itself");
        Check([c selectApplication:fixture] && c.validatedLaunchURL != nil && c.target == nil, @"Selects GLM without starting it");
        NSRunningApplication *a = Open(fixture, YES);
        Check(a && Wait(8, ^BOOL{ return [c.target isEqual:a] && a.active; }), @"Tracks the selected running app by identity and path");
        Spin(1.2);
        Check(!a.hidden, @"Automatic hide leaves foreground GLM available");
        NSURL *finderURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:@"com.apple.finder"];
        Check(finderURL != nil && Open(finderURL, YES) != nil, @"Switches away from the GLM fixture");
        Check(Wait(8, ^BOOL{ return a.hidden; }), @"Automatic hide runs after switching away");
        Check([c showTarget] && Wait(6, ^BOOL{ return !a.hidden; }), @"Show restores the running GLM process");
        Spin(1.1);
        Check(!a.hidden, @"Manual show cancels the pending automatic hide");
        Check([c hideTarget] && Wait(5, ^BOOL{ return a.hidden; }), @"Manual hide keeps the target alive");
        [c stop];
        Check(Wait(5, ^BOOL{ return !a.hidden && !a.terminated; }), @"Stopping the controller restores only its own hide");
        [a hide]; Check(Wait(5, ^BOOL{ return a.hidden; }), @"User hides GLM independently");
        c = [[GLMController alloc] initWithDefaults:prefs delay:0.5];
        Check([c.target isEqual:a], @"Selection persists and attaches to an already running app");
        [c stop]; Spin(0.4);
        Check(a.hidden, @"A previously hidden app stays hidden on helper exit");
        End(a);

        // Exercise the installed release binary through Launch Services with the same preferences the picker writes.
        NSString *prodID = [NSBundle bundleWithURL:helper].bundleIdentifier;
        NSUserDefaults *actual = [[NSUserDefaults alloc] initWithSuiteName:prodID];
        [actual setObject:[prefs dictionaryForKey:@"GLMSelection"] forKey:@"GLMSelection"];
        [actual setBool:YES forKey:@"OfferedSelection"];
        [actual setBool:YES forKey:@"AutoHide"];
        [actual synchronize];
        NSRunningApplication *resident = Open(helper, NO);
        Check(resident && resident.activationPolicy == NSApplicationActivationPolicyAccessory, @"Installed release runs as a menu-bar agent");
        Check([NSRunningApplication runningApplicationsWithBundleIdentifier:[NSBundle bundleWithURL:fixture].bundleIdentifier].count == 0,
              @"Starting the installed helper leaves GLM stopped");
        a = Open(fixture, NO);
        Check(a != nil && Open(finderURL, YES) != nil && Wait(22, ^BOOL{ return a.hidden; }), @"Installed release automatically hides GLM");
        pid_t pid = resident.processIdentifier;
        NSDictionary *idle = MeasureIdle(pid);
        NSRunningApplication *reopened = Open(helper, YES);
        Check(reopened.processIdentifier == pid && Wait(6, ^BOOL{ return !a.hidden; }), @"Reopening the installed helper shows GLM with one running helper");
        End(a);
        a = Open(fixture, NO);
        Check(a && Open(finderURL, YES) != nil && Wait(22, ^BOOL{ return a.hidden; }), @"Installed helper follows a replacement GLM process");
        End(resident);
        Check(Wait(5, ^BOOL{ return !a.hidden && !a.terminated; }), @"Quitting the installed helper restores GLM without terminating it");
        End(a);
        NSDictionary *report = @{@"passed": @YES, @"checks": checks, @"idle": idle,
            @"version": [[NSBundle bundleWithURL:helper] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
            @"platform": NSProcessInfo.processInfo.operatingSystemVersionString,
            @"commit": NSProcessInfo.processInfo.environment[@"GITHUB_SHA"] ?: @"local"};
        NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL];
        if (![json writeToFile:@(argv[3]) atomically:YES]) return 2;
        NSLog(@"Idle measurement: %@", idle);
    }
    return 0;
}
