#import <AppKit/AppKit.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "GLMController.h"

static NSString *L(NSString *english, NSString *chinese) {
    return [NSLocale.preferredLanguages.firstObject hasPrefix:@"zh"] ? chinese : english;
}

static void ActivateHelper(void) {
    if (@available(macOS 14.0, *)) [NSApp activate];
    else [NSApp activateIgnoringOtherApps:YES];
}

static void Message(NSString *title, NSString *details) {
    ActivateHelper();
    NSAlert *alert = [NSAlert new];
    alert.messageText = title;
    alert.informativeText = details;
    [alert runModal];
}

@interface TrayApp : NSObject <NSApplicationDelegate, NSMenuDelegate>
@end

@implementation TrayApp {
    GLMController *_glm;
    NSStatusItem *_item;
    NSMenuItem *_status, *_show, *_hide, *_automatic, *_login;
    BOOL _choosing, _launching;
}

- (NSMenuItem *)item:(NSString *)title action:(SEL)action menu:(NSMenu *)menu {
    NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:@""];
    item.target = self;
    return item;
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    _glm = [[GLMController alloc] initWithDefaults:NSUserDefaults.standardUserDefaults delay:10.0];
    _item = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    NSImage *icon = [NSImage imageWithSystemSymbolName:@"hifispeaker" accessibilityDescription:@"GLM Tray"];
    if (icon) { icon.template = YES; _item.button.image = icon; }
    else { _item.length = NSVariableStatusItemLength; _item.button.title = @"GLM"; }
    _item.button.toolTip = @"GLM Tray";
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"GLM Tray"];
    menu.autoenablesItems = NO;
    menu.delegate = self;
    _status = [self item:@"" action:NULL menu:menu];
    _status.enabled = NO;
    _show = [self item:@"" action:@selector(show:) menu:menu];
    _hide = [self item:L(@"Hide GLM", @"隐藏 GLM") action:@selector(hide:) menu:menu];
    [menu addItem:NSMenuItem.separatorItem];
    _automatic = [self item:L(@"Automatically hide GLM after launch", @"启动后自动隐藏 GLM")
                     action:@selector(toggleAutomatic:) menu:menu];
    _login = [self item:L(@"Open GLM Tray at login", @"登录时打开助手") action:@selector(toggleLogin:) menu:menu];
    [self item:L(@"Choose Genelec GLM…", @"选择 Genelec GLM…") action:@selector(choose:) menu:menu];
    [menu addItem:NSMenuItem.separatorItem];
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [self item:[NSString stringWithFormat:@"GLM Tray %@", version] action:NULL menu:menu].enabled = NO;
    [self item:L(@"Quit GLM Tray", @"退出 GLM Tray") action:@selector(quit:) menu:menu];
    _item.menu = menu;
    if (!_glm.selectedURL && ![NSUserDefaults.standardUserDefaults boolForKey:@"OfferedSelection"]) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"OfferedSelection"];
        dispatch_async(dispatch_get_main_queue(), ^{ [self choose:nil]; });
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSRunningApplication *target = _glm.target;
    if (!_glm.selectedURL) _status.title = L(@"Choose GLM to get started", @"请先选择原版 GLM");
    else if (!target || target.terminated) _status.title = L(@"Waiting for GLM", @"正在等待 GLM 启动");
    else if (target.hidden) _status.title = L(@"GLM is hidden", @"GLM 已在后台运行");
    else _status.title = L(@"GLM is visible", @"GLM 窗口已显示");
    _show.title = target && !target.terminated ? L(@"Show GLM", @"显示 GLM") : L(@"Open GLM…", @"打开 GLM…");
    _show.enabled = !_launching;
    _hide.enabled = target && !target.terminated && !target.hidden;
    _automatic.state = _glm.automaticallyHide ? NSControlStateValueOn : NSControlStateValueOff;
    SMAppServiceStatus login = SMAppService.mainAppService.status;
    _login.state = login == SMAppServiceStatusEnabled ? NSControlStateValueOn :
                  (login == SMAppServiceStatusRequiresApproval ? NSControlStateValueMixed : NSControlStateValueOff);
    _login.title = login == SMAppServiceStatusRequiresApproval ?
        L(@"Review login item in System Settings…", @"在系统设置中确认登录项…") :
        L(@"Open GLM Tray at login", @"登录时打开助手");
}

- (void)choose:(id)sender {
    if (_choosing) return;
    _choosing = YES;
    ActivateHelper();
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[UTTypeApplicationBundle];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.treatsFilePackagesAsDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.directoryURL = _glm.selectedURL.URLByDeletingLastPathComponent ?: [NSURL fileURLWithPath:@"/Applications" isDirectory:YES];
    panel.message = L(@"Select the Genelec GLM application you use to control your monitors.",
                      @"请选择平时用来控制监听音箱的 Genelec GLM 应用。");
    panel.prompt = L(@"Choose GLM", @"选择 GLM");
    if ([panel runModal] == NSModalResponseOK && ![_glm selectApplication:panel.URL]) {
        Message(L(@"Choose the original Genelec GLM app", @"请选择 Genelec 的原版 GLM 应用"),
                L(@"Open the menu again and select your installed GLM application.",
                  @"请在菜单中重新选择已安装的 GLM 应用。"));
    }
    _choosing = NO;
}

- (void)show:(id)sender {
    if (_glm.target && !_glm.target.terminated) {
        if (![_glm showTarget]) Message(L(@"Could not show GLM", @"无法显示 GLM"), L(@"Try opening GLM from the Dock.", @"请从程序坞打开 GLM。"));
        return;
    }
    if (_launching) return;
    NSURL *url = [_glm validatedLaunchURL];
    if (!url) { [self choose:sender]; return; }
    _launching = YES;
    NSWorkspaceOpenConfiguration *config = NSWorkspaceOpenConfiguration.configuration;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url configuration:config completionHandler:^(NSRunningApplication *app, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_launching = NO;
            if (error) Message(L(@"Could not open GLM", @"无法打开 GLM"), error.localizedDescription);
        });
    }];
}

- (void)hide:(id)sender {
    [_glm hideTargetWithCompletion:^(BOOL hidden) {
        if (!hidden) Message(L(@"Could not hide GLM", @"无法隐藏 GLM"),
            L(@"Finish any open dialog in GLM and try again.", @"请先处理 GLM 中的对话框，再试一次。"));
    }];
}

- (void)toggleAutomatic:(id)sender { _glm.automaticallyHide = !_glm.automaticallyHide; }

- (void)toggleLogin:(id)sender {
    SMAppService *service = SMAppService.mainAppService;
    if (service.status == SMAppServiceStatusRequiresApproval) { [SMAppService openSystemSettingsLoginItems]; return; }
    NSError *error = nil;
    BOOL ok = service.status == SMAppServiceStatusEnabled ? [service unregisterAndReturnError:&error] : [service registerAndReturnError:&error];
    if (service.status == SMAppServiceStatusRequiresApproval) { [SMAppService openSystemSettingsLoginItems]; return; }
    if (!ok) {
        ActivateHelper();
        NSAlert *alert = [NSAlert new];
        alert.messageText = L(@"Manage GLM Tray in Login Items", @"在「登录项」中管理 GLM Tray");
        alert.informativeText = [NSString stringWithFormat:@"%@\n\n%@", error.localizedDescription ?: @"",
            L(@"You can add or remove the installed GLM Tray app in System Settings.", @"可在系统设置中手动添加或移除已安装的 GLM Tray。")];
        [alert addButtonWithTitle:L(@"Open Login Items", @"打开登录项")];
        [alert addButtonWithTitle:L(@"Cancel", @"取消")];
        if ([alert runModal] == NSAlertFirstButtonReturn) [SMAppService openSystemSettingsLoginItems];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
    if (_glm.target && !_glm.target.terminated) [_glm showTarget];
    else if (_glm && !_glm.selectedURL && !_choosing) [self choose:nil];
    return NO;
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (void)applicationWillTerminate:(NSNotification *)note { [_glm stop]; }
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        __attribute__((objc_precise_lifetime)) TrayApp *delegate = [TrayApp new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
