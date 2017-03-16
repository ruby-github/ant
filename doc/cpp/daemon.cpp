#include <fstream>
#include <string>

#include <windows.h>

#define DEBUG 0

const std::string SERVICE_NAME = "ruby_daemon";
std::string cmdline = "";
std::ofstream logfile;

PROCESS_INFORMATION process_information = {
  NULL, NULL, 0, 0
};

SERVICE_STATUS service_status = {
  SERVICE_WIN32_OWN_PROCESS,
  SERVICE_STOPPED,
  SERVICE_ACCEPT_STOP,
  0, 0, 0, 0
};

SERVICE_STATUS_HANDLE service_status_handle = NULL;

void WINAPI service_main(DWORD argc, LPTSTR *argv);

int main(int argc, char *argv[]) {
  #if DEBUG
    logfile.open("C:/daemon.log");
  #endif

  for (int i = 1; i < argc; i++) {
    if (cmdline.empty()) {
      cmdline = std::string(argv[i]);
    } else {
      cmdline += " " + std::string(argv[i]);
    }
  }

  SERVICE_TABLE_ENTRY service_table[] = {
    {
      (LPSTR)SERVICE_NAME.c_str(), service_main
    },
    {
      NULL, NULL
    }
  };

  if (StartServiceCtrlDispatcher(service_table) == 0) {
    service_status.dwWin32ExitCode = GetLastError();
  }

  if (logfile) {
    logfile.close();
  }

  return service_status.dwWin32ExitCode;
}

// ---------------------------------------------------------

void set_service_status(DWORD status) {
  service_status.dwCurrentState = status;
  SetServiceStatus(service_status_handle, &service_status);
}

void handler(DWORD opcode) {
  switch (opcode) {
  case SERVICE_CONTROL_STOP:
    {
      set_service_status(SERVICE_STOP_PENDING);

      if (process_information.hProcess != NULL) {
        TerminateProcess(process_information.hProcess, 0);
      }

      break;
    }
  case SERVICE_CONTROL_SHUTDOWN:
    {
      if (service_status.dwCurrentState != SERVICE_STOPPED) {
        set_service_status(SERVICE_STOP_PENDING);

        if (process_information.hProcess != NULL) {
          TerminateProcess(process_information.hProcess, 0);
        }
      }

      break;
    }
  default :
    break;
  }
}

DWORD service_execute() {
  STARTUPINFO startupinfo;

  ZeroMemory(&startupinfo, sizeof(startupinfo));
  startupinfo.cb = sizeof(startupinfo);

  if (logfile) {
    logfile << "CreateProcess: " << cmdline << std::endl;
  }

  if (!CreateProcess(NULL, (LPSTR)cmdline.c_str(), NULL, NULL, FALSE, 0, NULL, NULL, &startupinfo, &process_information)) {
    if (logfile) {
      logfile << "CreateProcess FALSE: " << GetLastError() << std::endl;
    }

    return GetLastError();
  }

  set_service_status(SERVICE_RUNNING);

  WaitForSingleObject(process_information.hProcess, INFINITE);

  CloseHandle(process_information.hProcess);
  CloseHandle(process_information.hThread);

  return 0;
}

void WINAPI service_main(DWORD argc, LPTSTR *argv) {
  service_status.dwCurrentState = SERVICE_START_PENDING;

  service_status_handle = RegisterServiceCtrlHandler(SERVICE_NAME.c_str(), handler);

  if (service_status_handle != NULL) {
    set_service_status(SERVICE_START_PENDING);

    if (logfile) {
      logfile << "service starting ..." << std::endl;
    }

    service_status.dwWin32ExitCode = S_OK;
    service_status.dwCheckPoint = 0;
    service_status.dwWaitHint = 0;
    service_status.dwWin32ExitCode = service_execute();

    set_service_status(SERVICE_STOPPED);

    if (logfile) {
      logfile << "service stopped" << std::endl;
    }
  } else {
    if (logfile) {
      logfile << "handler not installed" << std::endl;
    }
  }
}