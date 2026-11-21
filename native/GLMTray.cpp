#define UNICODE
#define _UNICODE
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shellapi.h>
#include <sddl.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <string>
#include <vector>
#include <cwctype>
#include <cstdio>
#include <stdexcept>
#include <filesystem>
#include <shlobj.h>
#include <winver.h>
#include "logon-task.h"
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "uuid.lib")
#pragma comment(lib, "version.lib")
namespace fs = std::filesystem;

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "psapi.lib")

constexpr wchar_t Version[] = L"1.0.4";
constexpr wchar_t RunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr UINT TrayMessage = WM_APP + 1, WindowEvent = WM_APP + 2;
constexpr UINT IdShow = 1, IdHide = 2, IdExit = 3, IdStartup = 4, IdMinimize = 5, IdAbout = 6;
constexpr UINT_PTR AttachTimer = 1;
#ifdef GLMTRAY_TESTING
constexpr wchar_t RunValue[] = L"GLMTray.Test";
constexpr wchar_t ControllerClass[] = L"GLMTray.Test.Controller";
constexpr UINT StartupDelay = 1500;
#else
constexpr wchar_t RunValue[] = L"GLMTray";
constexpr wchar_t ControllerClass[] = L"GLMTray.Native.Controller";
constexpr UINT StartupDelay = 10000;
#endif

std::wstring SelfPath() {
    wchar_t path[32768]{};
    GetModuleFileNameW(nullptr, path, ARRAYSIZE(path));
    return path;
}
const fs::path& SettingsPath() {
    static const fs::path path = fs::path(SelfPath()).replace_extension(L".ini");
    return path;
}
std::wstring ResolveTarget() {
#ifdef GLMTRAY_TESTING
    return SelfPath();
#else
    wchar_t configured[32768]{};
    GetPrivateProfileStringW(L"GLMTray", L"GLMPath", L"", configured, ARRAYSIZE(configured), SettingsPath().c_str());
    if (*configured) {
        const auto path = (SettingsPath().parent_path() / configured).lexically_normal();
        return _wcsicmp(path.filename().c_str(), L"GLMv5.exe") == 0 ? path.wstring() : std::wstring();
    }
    // The vendor's uninstall registration follows the installation when a custom directory is selected.
    for (auto hive : {HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE}) {
        for (DWORD view : {RRF_SUBKEY_WOW6432KEY, RRF_SUBKEY_WOW6464KEY}) {
            wchar_t location[32768]{}, display[128]{};
            constexpr auto key = L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\22_is1";
            DWORD size = sizeof(display);
            if (RegGetValueW(hive, key, L"DisplayName", RRF_RT_REG_SZ | view, nullptr, display, &size) != ERROR_SUCCESS ||
                _wcsnicmp(display, L"GLM5", 4) != 0) continue;
            size = sizeof(location);
            if (RegGetValueW(hive, key, L"InstallLocation", RRF_RT_REG_SZ | view, nullptr, location, &size) != ERROR_SUCCESS) continue;
            const auto path = (fs::path(location) / L"GLMv5.exe").lexically_normal();
            if (path.is_absolute() && GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) return path.wstring();
        }
    }
    PWSTR programs{};
    if (FAILED(SHGetKnownFolderPath(FOLDERID_ProgramFilesX86, 0, nullptr, &programs))) return {};
    const auto path = fs::path(programs) / L"Genelec" / L"GLMv5" / L"GLMv5.exe";
    CoTaskMemFree(programs);
    return path.wstring();
#endif
}
const std::wstring& TargetPath() {
    static const auto path = ResolveTarget();
    return path;
}
std::wstring UserSid() {
    HANDLE token{};
    std::wstring sid;
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
        DWORD bytes{};
        GetTokenInformation(token, TokenUser, nullptr, 0, &bytes);
        std::vector<BYTE> buffer(bytes);
        if (GetTokenInformation(token, TokenUser, buffer.data(), bytes, &bytes)) {
            LPWSTR text{};
            if (ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &text)) {
                sid = text; LocalFree(text);
            }
        }
        CloseHandle(token);
    }
    return sid;
}
std::wstring Prefix() {
    const auto sid = UserSid();
    if (sid.empty()) return L"";
#ifdef GLMTRAY_TESTING
    return L"Local\\GLMTrayTest.CurrentUser." + sid;
#else
    return L"Local\\GLMTray.CurrentUser." + sid;
#endif
}
void Log(const wchar_t* message) {
    static const bool logging = GetPrivateProfileIntW(L"GLMTray", L"Diagnostics", 0, SettingsPath().c_str()) == 1;
    if (!logging) return;
    const auto path = fs::path(SelfPath()).replace_extension(L".log");
    FILE* file{};
    if (_wfopen_s(&file, path.c_str(), L"a, ccs=UTF-8") == 0) {
        SYSTEMTIME time{}; GetLocalTime(&time);
        fwprintf(file, L"%04u-%02u-%02u %02u:%02u:%02u %s\n", time.wYear, time.wMonth, time.wDay,
            time.wHour, time.wMinute, time.wSecond, message);
        fclose(file);
    }
}
std::wstring Title(HWND window) {
    wchar_t text[1024]{}; GetWindowTextW(window, text, ARRAYSIZE(text)); return text;
}
bool MainTitle(const std::wstring& text) {
    // Require the GLM numeric version: settings/help windows are not main windows.
    if (text.size() < 7 || text.compare(0, 3, L"GLM") != 0 || !iswspace(text[3])) return false;
    size_t i = 3;
    while (i < text.size() && iswspace(text[i])) ++i;
    if (i == text.size() || !iswdigit(text[i])) return false;
    while (i < text.size() && iswdigit(text[i])) ++i;
    return i + 1 < text.size() && text[i] == L'.' && iswdigit(text[i + 1]);
}
bool TargetProcess(DWORD pid) {
    DWORD session{}, mine{};
    if (!pid || !ProcessIdToSessionId(pid, &session) || !ProcessIdToSessionId(GetCurrentProcessId(), &mine) || session != mine) return false;
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!process) return false;
    wchar_t path[32768]{}; DWORD length = ARRAYSIZE(path);
    bool valid = QueryFullProcessImageNameW(process, 0, path, &length) && _wcsicmp(path, TargetPath().c_str()) == 0;
    CloseHandle(process); return valid;
}
bool TargetWindow(HWND window) {
    if (!IsWindow(window) || GetWindow(window, GW_OWNER) || (GetWindowLongPtrW(window, GWL_STYLE) & WS_CHILD)) return false;
    if (!MainTitle(Title(window))) return false;
    DWORD pid{}; GetWindowThreadProcessId(window, &pid);
    return TargetProcess(pid);
}
bool RunningTarget() {
    HANDLE list = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (list == INVALID_HANDLE_VALUE) return true;
    const auto full = TargetPath();
    const auto name = full.substr(full.find_last_of(L'\\') + 1);
    PROCESSENTRY32W e{}; e.dwSize = sizeof(e);
    bool found = false;
    for (BOOL more = Process32FirstW(list, &e); more; more = Process32NextW(list, &e)) {
        if (!_wcsicmp(name.c_str(), e.szExeFile) && TargetProcess(e.th32ProcessID)) { found = true; break; }
    }
    CloseHandle(list); return found;
}
BOOL CALLBACK FindCallback(HWND window, LPARAM param) {
    if (TargetWindow(window)) { *reinterpret_cast<HWND*>(param) = window; return FALSE; }
    return TRUE;
}
HWND FindMain() { HWND result{}; EnumWindows(FindCallback, reinterpret_cast<LPARAM>(&result)); return result; }
void Restore(HWND window, bool foreground) {
    if (!IsWindow(window)) return;
    ShowWindowAsync(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
    if (foreground) SetForegroundWindow(window);
}
struct DialogCheck { HWND main; DWORD pid; bool blocked; };
BOOL CALLBACK DialogCallback(HWND window, LPARAM param) {
    auto& check = *reinterpret_cast<DialogCheck*>(param);
    DWORD pid{}; GetWindowThreadProcessId(window, &pid);
    if (pid == check.pid && window != check.main && IsWindowVisible(window) && !Title(window).empty()) {
        RECT rect{}; GetWindowRect(window, &rect);
        if (rect.right > rect.left && rect.bottom > rect.top) { check.blocked = true; return FALSE; }
    }
    return TRUE;
}
bool CanHide(HWND window) {
    if (!IsWindow(window) || !IsWindowEnabled(window)) return false;
    DWORD pid{}; GetWindowThreadProcessId(window, &pid);
    DialogCheck check{window, pid, false}; EnumWindows(DialogCallback, reinterpret_cast<LPARAM>(&check));
    return !check.blocked;
}
std::wstring StartupValue() {
    wchar_t value[32768]{}; DWORD bytes = sizeof(value);
    if (RegGetValueW(HKEY_CURRENT_USER, RunKey, RunValue, RRF_RT_REG_SZ, nullptr, value, &bytes) != ERROR_SUCCESS) return L"";
    return value;
}
bool RemoveLegacyStartup() {
    const auto old = StartupValue();
    if (old.empty()) return true;
    int count{};
    auto args = CommandLineToArgvW(old.c_str(), &count);
    const bool shape = args && count == 2 && !wcscmp(args[1], L"--autostart");
    const fs::path prior = shape ? fs::path(args[0]) : fs::path();
    if (args) LocalFree(args);
    if (!prior.is_absolute() || _wcsicmp(prior.filename().c_str(), L"GLMTray.exe")) return false;
    // Only rebind an installed copy whose version resource identifies this product.
    // A missing portable copy may be relinked by an explicit enable request.
    if (GetFileAttributesW(prior.c_str()) != INVALID_FILE_ATTRIBUTES) {
        DWORD ignored{};
        const DWORD size = GetFileVersionInfoSizeW(prior.c_str(), &ignored);
        std::vector<BYTE> info(size);
        if (!size || !GetFileVersionInfoW(prior.c_str(), 0, size, info.data())) return false;
        struct Language { WORD language, page; };
        Language* languages{}; UINT length{};
        if (!VerQueryValueW(info.data(), L"\\VarFileInfo\\Translation", reinterpret_cast<void**>(&languages), &length)) return false;
        bool ours = false;
        for (size_t i = 0; i < length / sizeof(Language); ++i) {
            wchar_t field[80]{};
            swprintf_s(field, L"\\StringFileInfo\\%04x%04x\\ProductName", languages[i].language, languages[i].page);
            wchar_t* product{}; UINT chars{};
            if (VerQueryValueW(info.data(), field, reinterpret_cast<void**>(&product), &chars) &&
                chars && !_wcsicmp(product, L"GLM Tray")) { ours = true; break; }
        }
        if (!ours) return false;
    } else if (GetLastError() != ERROR_FILE_NOT_FOUND && GetLastError() != ERROR_PATH_NOT_FOUND) return false;
    HKEY key{};
    if (RegOpenKeyExW(HKEY_CURRENT_USER, RunKey, 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) return false;
    const bool unchanged = old == StartupValue();
    const LSTATUS result = unchanged ? RegDeleteValueW(key, RunValue) : ERROR_RETRY;
    RegCloseKey(key);
    return result == ERROR_SUCCESS || result == ERROR_FILE_NOT_FOUND;
}
bool StartupEnabled() { return LogonTask(LogonAction::Query, UserSid(), SelfPath()); }
// Setup queries a particular installed copy. A portable helper in the same
// session must not be stopped when another directory is being upgraded.
int InstalledState(const wchar_t* executable, bool stop) {
    if (!fs::path(executable).is_absolute()) return 8;
    HWND window = FindWindowW(ControllerClass, L"GLM Tray Controller");
    DWORD pid{};
    GetWindowThreadProcessId(window, &pid);
    int state = 0;
    if (pid) {
        HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, FALSE, pid);
        if (!process) return 8;
        wchar_t path[32768]{};
        DWORD length = ARRAYSIZE(path);
        bool queried = QueryFullProcessImageNameW(process, 0, path, &length) != FALSE;
        if (queried && !_wcsicmp(path, executable)) {
            state = 1;
            if (stop && (!PostMessageW(window, WM_CLOSE, 0, 0) ||
                         WaitForSingleObject(process, 10000) != WAIT_OBJECT_0)) state = 8;
        }
        CloseHandle(process);
        if (!queried) return 8;
    }
    if (stop) return state == 8 ? 8 : 0;
    const auto legacy = StartupValue();
    const auto expected = L"\"" + std::wstring(executable) + L"\" --autostart";
    if (LogonTask(LogonAction::Query, UserSid(), executable) || !_wcsicmp(legacy.c_str(), expected.c_str()))
        state |= 2;
    return state;
}
bool SetStartup(bool enable) {
    if (!LogonTask(enable ? LogonAction::Enable : LogonAction::Disable, UserSid(), SelfPath())) return false;
    return !enable || RemoveLegacyStartup();
}

void CALLBACK DiscoveryEvent(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD);
void CALLBACK TitleEvent(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD);
void CALLBACK WinEvent(HWINEVENTHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD);
struct App {
    HWND controller{}, target{};
    DWORD targetPid{};
    HANDLE process{};
    HANDLE signals[3]{};
    HICON icon{};
    std::vector<HWINEVENTHOOK> hooks;
    UINT taskbarCreated{};
    HWINEVENTHOOK discovery{}, titleHook{}, modalState{};
    DWORD titlePid{};
    ULONGLONG due{}, lastLaunch{};
    bool shellListening{}, showOnAttach{}, pendingHide{}, delayPassed{}, hideOnMinimize = true, quitting{}, iconAdded{};
    std::wstring lastTip;

    void WatchShell(bool enabled) {
        if (enabled == shellListening) return;
        if (enabled) {
            discovery = SetWinEventHook(EVENT_OBJECT_SHOW, EVENT_OBJECT_SHOW, nullptr, DiscoveryEvent, 0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
            shellListening = discovery != nullptr;
        } else {
            if (discovery) UnhookWinEvent(discovery);
            if (titleHook) UnhookWinEvent(titleHook);
            discovery = titleHook = nullptr; titlePid = 0; shellListening = false;
        }
    }
    bool ValidTarget() const {
        DWORD pid{};
        return target && process && WaitForSingleObject(process, 0) == WAIT_TIMEOUT &&
            GetWindowThreadProcessId(target, &pid) && pid == targetPid;
    }
    void UpdateTray(bool add = false) {
        std::wstring tip = L"GLM 托盘助手 1.0.4 · ";
        tip += !target ? L"等待 GLM" : IsWindowVisible(target) ? L"界面已显示" : L"已收进托盘";
        if (!add && tip == lastTip) return;
        NOTIFYICONDATAW data{}; data.cbSize = sizeof(data); data.hWnd = controller; data.uID = 1;
        data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP; data.uCallbackMessage = TrayMessage; data.hIcon = icon;
        wcsncpy_s(data.szTip, tip.c_str(), _TRUNCATE);
        if (Shell_NotifyIconW(add ? NIM_ADD : NIM_MODIFY, &data)) { lastTip = tip; iconAdded = true; }
    }
    void Balloon(const wchar_t* text) {
        NOTIFYICONDATAW data{}; data.cbSize = sizeof(data); data.hWnd = controller; data.uID = 1; data.uFlags = NIF_INFO;
        wcscpy_s(data.szInfoTitle, L"GLM 托盘助手"); wcsncpy_s(data.szInfo, text, _TRUNCATE); data.dwInfoFlags = NIIF_INFO;
        Shell_NotifyIconW(NIM_MODIFY, &data);
    }
    bool Hook(DWORD first, DWORD last, WINEVENTPROC callback) {
        auto hook = SetWinEventHook(first, last, nullptr, callback, targetPid, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
        if (!hook) return false;
        hooks.push_back(hook); return true;
    }
    void Detach(bool watch = true) {
        EndPending();
        for (auto hook : hooks) UnhookWinEvent(hook);
        hooks.clear(); if (process) CloseHandle(process);
        process = nullptr; target = nullptr; targetPid = 0; pendingHide = false; delayPassed = false;
        if (watch) { WatchShell(true); UpdateTray(); }
    }
    void Attach(HWND window);
    void EndPending() {
        pendingHide = false; KillTimer(controller, AttachTimer);
        if (modalState) { UnhookWinEvent(modalState); modalState = nullptr; }
    }
    void Hide(bool explicitRequest) {
        if (!iconAdded || !ValidTarget()) return;
        if (!CanHide(target)) {
            if (explicitRequest) Balloon(L"GLM 有其他窗口打开，请先完成或关闭它，再收进托盘。");
            if (pendingHide && !modalState) modalState = SetWinEventHook(EVENT_OBJECT_STATECHANGE,
                EVENT_OBJECT_STATECHANGE, nullptr, WinEvent, targetPid, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
            return;
        }
        EndPending();
        if (IsWindowVisible(target)) { ShowWindowAsync(target, SW_HIDE); Log(L"Hide requested"); }
    }
    void Show(bool launch) {
        if (!target) { HWND found = FindMain(); if (found) Attach(found); }
        EndPending();
        if (ValidTarget()) { Restore(target, true); showOnAttach = false; }
        else {
            showOnAttach = true;
            if (launch && !RunningTarget() && (!lastLaunch || GetTickCount64() - lastLaunch > 5000)) {
                lastLaunch = GetTickCount64();
                // Launch only on an explicit user action; never on process exit or at login.
                const auto exe = TargetPath(); const auto directory = exe.substr(0, exe.find_last_of(L'\\'));
                if (exe.empty() || GetFileAttributesW(exe.c_str()) == INVALID_FILE_ATTRIBUTES ||
                    reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", exe.c_str(), nullptr, directory.c_str(), SW_SHOWNORMAL)) <= 32)
                    Balloon(L"无法启动 GLM，请检查程序安装路径。");
            }
        }
        Log(L"Show requested");
    }
    void Menu() {
        HMENU menu = CreatePopupMenu();
        AppendMenuW(menu, MF_STRING, IdShow, L"显示 GLM");
        AppendMenuW(menu, MF_STRING, IdHide, L"隐藏到托盘");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING | (hideOnMinimize ? MF_CHECKED : 0), IdMinimize, L"最小化时收进托盘");
        AppendMenuW(menu, MF_STRING | (StartupEnabled() ? MF_CHECKED : 0), IdStartup, L"登录 Windows 后启动助手");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING, IdAbout, L"关于 GLM 托盘助手 1.0.4");
        AppendMenuW(menu, MF_STRING, IdExit, L"退出助手并恢复 GLM");
        POINT point{}; GetCursorPos(&point); SetForegroundWindow(controller);
        UINT command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, controller, nullptr);
        DestroyMenu(menu); PostMessageW(controller, WM_NULL, 0, 0);
        if (command) PostMessageW(controller, WM_COMMAND, command, 0);
    }
    void Command(UINT command) {
        if (command == IdShow) Show(true);
        else if (command == IdHide) Hide(true);
        else if (command == IdExit) quitting = true;
        else if (command == IdStartup) {
            if (!SetStartup(!StartupEnabled())) Balloon(L"登录任务或旧启动项未能完成更新，请检查 Windows 任务计划程序。");
        } else if (command == IdMinimize) {
            if (WritePrivateProfileStringW(L"GLMTray", L"HideOnMinimize", hideOnMinimize ? L"0" : L"1", SettingsPath().c_str()))
                hideOnMinimize = !hideOnMinimize;
            else Balloon(L"此目录无法保存设置。请将助手放在可以写入的目录。");
        } else if (command == IdAbout) MessageBoxW(controller,
            L"GLM 托盘助手 1.0.4\n\n双击托盘图标恢复 GLM，最小化时自动收起。\n退出助手会恢复 GLM 窗口。\n\n原生事件驱动，无后台定时轮询。", L"GLM 托盘助手", MB_OK);
    }
    void OnEvent(DWORD event, HWND window) {
        if (!target) return;
        if (event == EVENT_OBJECT_DESTROY && window == target) { Detach(); return; }
        if (!ValidTarget()) { Detach(); return; }
        if (window == target && event == EVENT_SYSTEM_MINIMIZESTART && hideOnMinimize) Hide(false);
        else if (pendingHide && delayPassed) Hide(false);
        if (window == target && (event == EVENT_OBJECT_SHOW || event == EVENT_OBJECT_HIDE)) UpdateTray();
    }
    ~App() {
        if (ValidTarget()) Restore(target, false);
        Detach(false);
        WatchShell(false);
        if (iconAdded) { NOTIFYICONDATAW data{}; data.cbSize = sizeof(data); data.hWnd = controller; data.uID = 1; Shell_NotifyIconW(NIM_DELETE, &data); }
        if (controller) DestroyWindow(controller);
        if (icon) DestroyIcon(icon);
        for (auto signal : signals) if (signal) CloseHandle(signal);
    }
};
App* app{};
void CALLBACK DiscoveryEvent(HWINEVENTHOOK hook, DWORD, HWND window, LONG object, LONG child, DWORD, DWORD) {
    if (!app || hook != app->discovery || !window || object != OBJID_WINDOW || child != CHILDID_SELF ||
        GetAncestor(window, GA_ROOT) != window || GetWindow(window, GW_OWNER)) return;
    DWORD pid{}; GetWindowThreadProcessId(window, &pid);
    if (!TargetProcess(pid)) return;
    if (pid != app->titlePid || !app->titleHook) {
        if (app->titleHook) UnhookWinEvent(app->titleHook);
        app->titlePid = pid;
        app->titleHook = SetWinEventHook(EVENT_OBJECT_NAMECHANGE, EVENT_OBJECT_NAMECHANGE, nullptr, TitleEvent,
            pid, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
    }
    app->Attach(window);
}
void CALLBACK TitleEvent(HWINEVENTHOOK hook, DWORD, HWND window, LONG object, LONG child, DWORD, DWORD) {
    if (app && hook == app->titleHook && window && object == OBJID_WINDOW && child == CHILDID_SELF) app->Attach(window);
}
void CALLBACK WinEvent(HWINEVENTHOOK, DWORD event, HWND window, LONG object, LONG child, DWORD, DWORD) {
    if (app && app->target && window && object == OBJID_WINDOW && child == CHILDID_SELF &&
        (window == app->target || (app->pendingHide && app->delayPassed &&
        (event == EVENT_OBJECT_HIDE || event == EVENT_OBJECT_DESTROY || event == EVENT_SYSTEM_DIALOGEND))))
        PostMessageW(app->controller, WindowEvent, event, reinterpret_cast<LPARAM>(window));
}
void App::Attach(HWND window) {
    if (target || !TargetWindow(window)) return;
    target = window; GetWindowThreadProcessId(target, &targetPid);
    process = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, targetPid);
    if (!process) { target = nullptr; targetPid = 0; return; }
    if (!Hook(EVENT_SYSTEM_MINIMIZESTART, EVENT_SYSTEM_MINIMIZESTART, WinEvent) ||
        !Hook(EVENT_OBJECT_DESTROY, EVENT_OBJECT_HIDE, WinEvent) ||
        !Hook(EVENT_SYSTEM_DIALOGEND, EVENT_SYSTEM_DIALOGEND, WinEvent)) {
        Log(L"Target event registration failed; GLM left visible"); Detach(); return;
    }
    WatchShell(false);
    if (showOnAttach) { showOnAttach = false; Restore(target, true); }
    else { pendingHide = true; delayPassed = false; due = GetTickCount64() + StartupDelay; SetTimer(controller, AttachTimer, StartupDelay, nullptr); }
    UpdateTray(); Log(L"Attached to GLM; global discovery disabled");
}
LRESULT CALLBACK ControllerProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    if (!app) return DefWindowProcW(window, message, wparam, lparam);
    if (message == app->taskbarCreated && app->controller) {
        app->iconAdded = false; app->UpdateTray(true);
        if (!app->iconAdded && app->ValidTarget()) Restore(app->target, false);
        if (app->iconAdded && app->pendingHide && app->delayPassed) app->Hide(false);
        return 0;
    }
    switch (message) {
        case TrayMessage:
            if (lparam == WM_LBUTTONDBLCLK) app->Show(true);
            else if (lparam == WM_RBUTTONUP || lparam == WM_CONTEXTMENU) app->Menu();
            return 0;
        case WindowEvent: app->OnEvent(static_cast<DWORD>(wparam), reinterpret_cast<HWND>(lparam)); return 0;
        case WM_COMMAND: app->Command(LOWORD(wparam)); return 0;
        case WM_TIMER:
            if (wparam == AttachTimer && app->pendingHide && GetTickCount64() >= app->due) { KillTimer(window, AttachTimer); app->delayPassed = true; app->Hide(false); }
            return 0;
        case WM_QUERYENDSESSION: return TRUE;
        case WM_ENDSESSION: if (wparam) app->quitting = true; return 0;
        case WM_CLOSE: app->quitting = true; return 0;
    }
    return DefWindowProcW(window, message, wparam, lparam);
}
bool Signal(const std::wstring& prefix, const wchar_t* command) {
    HANDLE event = OpenEventW(EVENT_MODIFY_STATE, FALSE, (prefix + L"." + command).c_str());
    if (!event) return false; SetEvent(event); CloseHandle(event); return true;
}
bool WriteInspect(const wchar_t* output) {
    HWND window = FindMain(); DWORD pid{}; GetWindowThreadProcessId(window, &pid);
    FILE* file{};
    if (_wfopen_s(&file, output, L"w, ccs=UTF-8")) return false;
    fwprintf(file, L"{\"version\":\"1.0.4\",\"hwnd\":%llu,\"pid\":%lu,\"visible\":%s,\"minimized\":%s,\"enabled\":%s}\n",
        static_cast<unsigned long long>(reinterpret_cast<UINT_PTR>(window)), pid,
        IsWindowVisible(window) ? L"true" : L"false", IsIconic(window) ? L"true" : L"false", IsWindowEnabled(window) ? L"true" : L"false");
    fclose(file); return true;
}

#ifdef GLMTRAY_TESTING
HWND fixtureMain{}, fixtureDialog{};
LRESULT CALLBACK FixtureProc(HWND window, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_APP + 20) {
        if (wp == 1) ShowWindow(window, SW_SHOWNOACTIVATE);
        if (wp == 2) ShowWindow(window, SW_MINIMIZE);
        if (wp == 3) {
            fixtureDialog = CreateWindowExW(WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW, L"STATIC", L"MIDI Settings Test",
                WS_OVERLAPPEDWINDOW, -20000, -20000, 250, 100, window, nullptr, nullptr, nullptr);
            ShowWindow(fixtureDialog, SW_SHOWNOACTIVATE); EnableWindow(window, FALSE);
        }
        if (wp == 4) { DestroyWindow(fixtureDialog); fixtureDialog = nullptr; EnableWindow(window, TRUE); NotifyWinEvent(EVENT_SYSTEM_DIALOGEND, window, OBJID_WINDOW, CHILDID_SELF); }
        if (wp == 5) DestroyWindow(window);
        return 0;
    }
    if (msg == WM_TIMER) { KillTimer(window, 9); SetWindowTextW(window, L"GLM  5.2.0 [ native self test ]"); return 0; }
    if (msg == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(window, msg, wp, lp);
}
int Fixture(HINSTANCE instance) {
    WNDCLASSW wc{}; wc.lpfnWndProc = FixtureProc; wc.hInstance = instance; wc.lpszClassName = L"GLMTray.TestFixture";
    RegisterClassW(&wc);
    fixtureMain = CreateWindowExW(WS_EX_NOACTIVATE, wc.lpszClassName, L"Loading fixture", WS_OVERLAPPEDWINDOW,
        -20000, -20000, 250, 100, nullptr, nullptr, instance, nullptr);
    ShowWindow(fixtureMain, SW_HIDE);
    ShowWindow(fixtureMain, SW_SHOWNOACTIVATE); SetTimer(fixtureMain, 9, 250, nullptr);
    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) { TranslateMessage(&message); DispatchMessageW(&message); }
    return 0;
}
#endif

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, LPWSTR, int) {
    int argc{}; LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    std::wstring command = argc > 1 ? argv[1] : L"";
#ifdef GLMTRAY_TESTING
    if (command == L"--fixture") { LocalFree(argv); return Fixture(instance); }
#endif
    if (command == L"--inspect" && argc == 3) { bool ok = WriteInspect(argv[2]); LocalFree(argv); return ok ? 0 : 1; }
    if (argc == 3 && (command == L"--setup-state" || command == L"--setup-stop")) {
        const int result = InstalledState(argv[2], command == L"--setup-stop");
        LocalFree(argv); return result;
    }
    LocalFree(argv);
    if (command == L"--enable-startup") return SetStartup(true) ? 0 : 1;
    if (command == L"--disable-startup") return SetStartup(false) ? 0 : 1;
    auto prefix = Prefix(); if (prefix.empty()) return 1;
    if (command == L"--show" || command == L"--hide" || command == L"--exit") {
        if (Signal(prefix, command.substr(2).c_str())) return 0;
        if (command == L"--hide") return 2;
        Restore(FindMain(), true); return 0;
    }
    if (!command.empty() && command != L"--autostart") return 2;
    HANDLE mutex = CreateMutexW(nullptr, FALSE, (prefix + L".instance").c_str());
    if (!mutex) return 1;
    if (GetLastError() == ERROR_ALREADY_EXISTS) { if (command.empty()) Signal(prefix, L"show"); CloseHandle(mutex); return 0; }
    int result = 0;
    try {
        App state; app = &state; state.showOnAttach = command.empty();
        const wchar_t* names[]{L"show", L"hide", L"exit"};
        for (int i = 0; i < 3; ++i) { state.signals[i] = CreateEventW(nullptr, FALSE, FALSE, (prefix + L"." + names[i]).c_str()); if (!state.signals[i]) throw std::runtime_error("IPC event failed"); }
        DWORD setting = 1, bytes = sizeof(setting);
        RegGetValueW(HKEY_CURRENT_USER, L"Software\\GLMTray", L"HideOnMinimize", RRF_RT_REG_DWORD, nullptr, &setting, &bytes);
        state.hideOnMinimize = GetPrivateProfileIntW(L"GLMTray", L"HideOnMinimize", setting != 0, SettingsPath().c_str()) != 0;
        WNDCLASSW wc{}; wc.lpfnWndProc = ControllerProc; wc.hInstance = instance; wc.lpszClassName = ControllerClass;
        RegisterClassW(&wc);
        state.controller = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, ControllerClass, L"GLM Tray Controller", WS_POPUP,
            0, 0, 0, 0, nullptr, nullptr, instance, nullptr);
        if (!state.controller) throw std::runtime_error("Controller window failed");
        state.taskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
        state.icon = static_cast<HICON>(LoadImageW(instance, MAKEINTRESOURCEW(101), IMAGE_ICON,
            GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), LR_DEFAULTCOLOR)); state.UpdateTray(true); state.WatchShell(true);
        if (!state.shellListening || !state.icon) throw std::runtime_error("Tray/discovery setup failed");
        HWND target = FindMain();
        if (target) state.Attach(target);
        else {
            // A splash window can predate the helper, then acquire its GLM title later.
            EnumWindows([](HWND w, LPARAM) -> BOOL {
                if (IsWindowVisible(w)) DiscoveryEvent(app->discovery, EVENT_OBJECT_SHOW, w, OBJID_WINDOW, CHILDID_SELF, 0, 0);
                return !app->target;
            }, 0);
        }
        Log(L"Native 1.0.4 started; no periodic polling");
        while (!state.quitting) {
            HANDLE handles[]{state.signals[0], state.signals[1], state.signals[2], state.process};
            DWORD count = state.process ? 4 : 3;
            DWORD wait = MsgWaitForMultipleObjectsEx(count, handles, INFINITE, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
            if (wait == WAIT_FAILED) throw std::runtime_error("Message wait failed");
            if (wait == WAIT_OBJECT_0) state.Show(false);
            else if (wait == WAIT_OBJECT_0 + 1) state.Hide(false);
            else if (wait == WAIT_OBJECT_0 + 2) state.quitting = true;
            else if (state.process && wait == WAIT_OBJECT_0 + 3) state.Detach();
            MSG message{};
            while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
                if (message.message == WM_QUIT) { state.quitting = true; break; }
                TranslateMessage(&message); DispatchMessageW(&message);
            }
        }
        Log(L"Native helper exited; restoring GLM");
    } catch (...) {
        result = 1; Log(L"Native helper error; restoring GLM"); Restore(FindMain(), false);
    }
    app = nullptr; CloseHandle(mutex); return result;
}
