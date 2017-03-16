#include <fstream>

#include <userenv.h>
#include <windows.h>
#include <wtsapi32.h>

#ifdef __cplusplus
extern "C" {
#endif

__declspec(dllexport)
int create_user_process(const char* cmdline, bool async = false, bool debug = false) {
  std::ofstream logfile;

  if (debug) {
    logfile.open("C:/function.log");
  }

  DWORD dwSessionId = 0;

  WTS_SESSION_INFOA *pSessionInfo = NULL;
  DWORD dwSessionInfoCount = 0;

  if (!WTSEnumerateSessions(WTS_CURRENT_SERVER_HANDLE, 0, 1, &pSessionInfo, &dwSessionInfoCount)) {
    if (logfile) {
      logfile << "WTSEnumerateSessions FALSE: " << GetLastError() << std::endl;
    }

    pSessionInfo = NULL;
    dwSessionInfoCount = 0;
  }

  if (logfile) {
    logfile << "dwSessionInfoCount: " << dwSessionInfoCount << std::endl;
  }

  for (DWORD i = 0; i < dwSessionInfoCount; i++) {
    // Query Active Session

    WTS_CONNECTSTATE_CLASS *pwtsConnectState = NULL;
    DWORD dwBytesReturned = 0;

    if (!WTSQuerySessionInformation(WTS_CURRENT_SERVER_HANDLE, pSessionInfo[i].SessionId,
        WTSConnectState, (LPTSTR*)&pwtsConnectState, &dwBytesReturned)) {
      if (logfile) {
        logfile << "WTSQuerySessionInformation WTSConnectState(" << pSessionInfo[i].SessionId << ") FALSE: " << GetLastError() << std::endl;
      }

      continue;
    }

    WTS_CONNECTSTATE_CLASS wtsConnectState = *pwtsConnectState;
    WTSFreeMemory(pwtsConnectState);

    if (wtsConnectState != WTSActive) {
      if (logfile) {
        logfile << "WTSQuerySessionInformation WTSConnectState(" << pSessionInfo[i].SessionId << "): NO WTSActive" << std::endl;
      }

      continue;
    } else {
      if (logfile) {
        logfile << "WTSQuerySessionInformation WTSConnectState(" << pSessionInfo[i].SessionId << "): WTSActive" << std::endl;
      }
    }

    if (dwSessionId == 0) {
      dwSessionId = pSessionInfo[i].SessionId;
    }

    // Query Active Session UserName

    LPTSTR pBuffer = NULL;
    DWORD bufferSize = 0;

    if (!WTSQuerySessionInformation(WTS_CURRENT_SERVER_HANDLE, pSessionInfo[i].SessionId,
      WTSUserName, &pBuffer, &bufferSize)) {
      if (logfile) {
        logfile << "WTSQuerySessionInformation WTSUserName(" << pSessionInfo[i].SessionId << ") FALSE: " << GetLastError() << std::endl;
      }

      continue;
    }

    std::string username = std::string(pBuffer);
    WTSFreeMemory(pBuffer);

    if (logfile) {
      logfile << "WTSQuerySessionInformation WTSUserName(" << pSessionInfo[i].SessionId << "): " << username << std::endl;
    }

    if (username == "Administrator") {
      dwSessionId = pSessionInfo[i].SessionId;
    }
  }

  if (dwSessionId == 0) {
    dwSessionId = WTSGetActiveConsoleSessionId();
  }

  if (logfile) {
    logfile << "dwSessionId: " << dwSessionId << std::endl;
  }

  HANDLE hToken = NULL;

  if (!WTSQueryUserToken(dwSessionId, &hToken)) {
    if (logfile) {
      logfile << "WTSQueryUserToken FALSE: " << GetLastError() << std::endl;
    }

    hToken = NULL;
  }

  if (logfile) {
    logfile << "hToken: " << hToken << std::endl;
  }

  HANDLE hDupToken = NULL;

  if (hToken != NULL) {
    if (!DuplicateTokenEx(hToken, MAXIMUM_ALLOWED, NULL, SecurityIdentification, TokenPrimary, &hDupToken)) {
      if (logfile) {
        logfile << "DuplicateTokenEx FALSE: " << GetLastError() << std::endl;
      }

      hDupToken = NULL;
    }

    if (logfile) {
      logfile << "hDupToken: " << hDupToken << std::endl;
    }
  }

  LPVOID lpEnvironment = NULL;
  DWORD dwCreationFlag = NORMAL_PRIORITY_CLASS | CREATE_NEW_CONSOLE;

  if (CreateEnvironmentBlock(&lpEnvironment, hDupToken, FALSE)) {
    dwCreationFlag |= CREATE_UNICODE_ENVIRONMENT;
  } else {
    if (logfile) {
      logfile << "CreateEnvironmentBlock FALSE: " << GetLastError() << std::endl;
    }

    lpEnvironment = NULL;
  }

  if (logfile) {
    logfile << "lpEnvironment: " << lpEnvironment << std::endl;
    logfile << "dwCreationFlag: " << dwCreationFlag << std::endl;
  }

  STARTUPINFO startupinfo;

  ZeroMemory(&startupinfo, sizeof(startupinfo));
  startupinfo.cb = sizeof(startupinfo);

  PROCESS_INFORMATION process_information = {
    NULL, NULL, 0, 0
  };

  if (hDupToken != NULL) {
    if (logfile) {
      logfile << "CreateProcessAsUser: " << cmdline << std::endl;
    }

    if (!CreateProcessAsUser(hDupToken, NULL, (LPSTR)cmdline, NULL, NULL, FALSE, dwCreationFlag, lpEnvironment, NULL, &startupinfo, &process_information)) {
      if (logfile) {
        logfile << "CreateProcessAsUser FALSE: " << GetLastError() << std::endl;
        logfile.close();
      }

      return GetLastError();
    }
  } else {
    if (logfile) {
      logfile << "CreateProcess: " << cmdline << std::endl;
    }

    if (!CreateProcess(NULL, (LPSTR)cmdline, NULL, NULL, FALSE, 0, NULL, NULL, &startupinfo, &process_information)) {
      if (logfile) {
        logfile << "CreateProcess FALSE: " << GetLastError() << std::endl;
        logfile.close();
      }

      return GetLastError();
    }
  }

  DWORD dwExitCode = 0;

  if (!async) {
    WaitForSingleObject(process_information.hProcess, INFINITE);

    GetExitCodeProcess(process_information.hProcess, &dwExitCode);
  }

  CloseHandle(process_information.hProcess);
  CloseHandle(process_information.hThread);

  if (logfile) {
    logfile.close();
  }

  return dwExitCode;
}

#ifdef __cplusplus
}
#endif