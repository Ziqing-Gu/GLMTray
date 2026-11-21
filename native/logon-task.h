#pragma once
#include <string>

enum class LogonAction { Query, Enable, Disable };
bool LogonTask(LogonAction action, const std::wstring& sid, const std::wstring& executable);
