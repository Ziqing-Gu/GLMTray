#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <taskschd.h>
#include <wrl/client.h>
#include <comdef.h>
#include "logon-task.h"
#pragma comment(lib, "taskschd.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "comsuppw.lib")

namespace {
using Microsoft::WRL::ComPtr;
constexpr wchar_t Source[] = L"Qing Audio GLM Tray";
#ifdef GLMTRAY_TESTING
constexpr wchar_t TaskPrefix[] = L"GLM Tray Test - ";
#else
constexpr wchar_t TaskPrefix[] = L"GLM Tray - ";
#endif

void Check(HRESULT result) {
    if (FAILED(result)) _com_issue_error(result);
}

class Apartment {
    HRESULT result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
public:
    Apartment() { if (result != RPC_E_CHANGED_MODE) Check(result); }
    ~Apartment() { if (SUCCEEDED(result)) CoUninitialize(); }
};

struct Registration {
    bool exists{}, owned{}, currentPath{}, enabled{};
};

Registration Inspect(ITaskFolder* folder, BSTR name, const std::wstring& executable) {
    ComPtr<IRegisteredTask> task;
    HRESULT hr = folder->GetTask(name, &task);
    if (hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND) || hr == HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)) return {};
    Check(hr);
    Registration state;
    state.exists = true;
    ComPtr<ITaskDefinition> def;
    ComPtr<IRegistrationInfo> info;
    Check(task->get_Definition(&def));
    Check(def->get_RegistrationInfo(&info));
    _bstr_t source;
    Check(info->get_Source(source.GetAddress()));
    state.owned = source.length() && wcscmp(source, Source) == 0;
    if (!state.owned) return state;
    ComPtr<IActionCollection> actions;
    Check(def->get_Actions(&actions));
    LONG count{};
    Check(actions->get_Count(&count));
    if (count != 1) return state;
    ComPtr<IAction> action;
    ComPtr<IExecAction> exec;
    Check(actions->get_Item(1, &action));
    Check(action.As(&exec));
    _bstr_t program, args;
    Check(exec->get_Path(program.GetAddress()));
    Check(exec->get_Arguments(args.GetAddress()));
    state.currentPath = program.length() && !_wcsicmp(program, executable.c_str()) &&
                        args.length() && !wcscmp(args, L"--autostart");
    VARIANT_BOOL enabled{};
    Check(task->get_Enabled(&enabled));
    state.enabled = enabled == VARIANT_TRUE;
    return state;
}

std::wstring EscapeXml(const std::wstring& value) {
    std::wstring escaped;
    for (wchar_t c : value) {
        if (c == L'&') escaped += L"&amp;";
        else if (c == L'<') escaped += L"&lt;";
        else if (c == L'>') escaped += L"&gt;";
        else escaped += c;
    }
    return escaped;
}
}

bool LogonTask(LogonAction action, const std::wstring& sid, const std::wstring& executable) {
    if (sid.empty()) return false;
    try {
        Apartment apartment;
        ComPtr<ITaskService> service;
        Check(CoCreateInstance(CLSID_TaskScheduler, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&service)));
        _variant_t empty;
        Check(service->Connect(empty, empty, empty, empty));
        ComPtr<ITaskFolder> folder;
        Check(service->GetFolder(_bstr_t(L"\\"), &folder));
        _bstr_t name((TaskPrefix + sid).c_str());
        const Registration state = Inspect(folder.Get(), name, executable);
        if (action == LogonAction::Query) return state.currentPath && state.enabled;
        if (state.exists && !state.owned) return false;
        if (action == LogonAction::Disable) {
            if (state.currentPath) Check(folder->DeleteTask(name, 0));
            return true; // Uninstalling an older copy must preserve the active copy's task.
        }
        if (state.currentPath && state.enabled) return true;
        const std::wstring xml =
            L"<Task version=\"1.2\" xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">"
            L"<RegistrationInfo><Source>" + std::wstring(Source) + L"</Source></RegistrationInfo>"
            L"<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>" + sid + L"</UserId></LogonTrigger></Triggers>"
            L"<Principals><Principal id=\"User\"><UserId>" + sid + L"</UserId>"
            L"<LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>"
            L"<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>"
            L"<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>"
            L"<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><StartWhenAvailable>true</StartWhenAvailable>"
            L"<ExecutionTimeLimit>PT0S</ExecutionTimeLimit></Settings>"
            L"<Actions Context=\"User\"><Exec><Command>" + EscapeXml(executable) +
            L"</Command><Arguments>--autostart</Arguments></Exec></Actions></Task>";
        ComPtr<IRegisteredTask> registered;
        Check(folder->RegisterTask(name, _bstr_t(xml.c_str()), state.exists ? TASK_UPDATE : TASK_CREATE,
            _variant_t(sid.c_str()), empty, TASK_LOGON_INTERACTIVE_TOKEN, empty, &registered));
        const Registration saved = Inspect(folder.Get(), name, executable);
        return saved.currentPath && saved.enabled;
    } catch (const _com_error&) {
        return false;
    }
}
