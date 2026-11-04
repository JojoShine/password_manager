#ifndef RUNNER_LOCKORA_UPDATER_H_
#define RUNNER_LOCKORA_UPDATER_H_

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <atomic>
#include <memory>

class LockoraUpdater {
 public:
  LockoraUpdater(HWND window, flutter::BinaryMessenger* messenger);
  ~LockoraUpdater();
  bool HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
 private:
  struct Preparation {
    HANDLE event = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    std::atomic<bool> allowed{false};
    std::atomic<bool> expired{false};
    std::atomic<bool> completed{false};
    ~Preparation() { CloseHandle(event); }
    bool Complete(bool prepared) {
      if (!expired.load()) allowed.store(prepared);
      completed.store(true);
      SetEvent(event);
      return !expired.load();
    }
  };
  void Status(const char* status, const char* message = nullptr);
  static void PostStatus(int status);
  static int __cdecl CanShutdown();
  static void __cdecl Shutdown();
  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::atomic<bool> can_install_{false};
  HANDLE stopping_;
  bool configured_ = false;
  std::shared_ptr<Preparation> active_preparation_;
  static LockoraUpdater* instance_;
  static constexpr UINT kStatusMessage = WM_APP + 71;
  static constexpr UINT kPrepareMessage = WM_APP + 72;
  static constexpr UINT kShutdownMessage = WM_APP + 73;
};
#endif
