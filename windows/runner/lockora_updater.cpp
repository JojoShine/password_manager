#include "lockora_updater.h"

#include <flutter/standard_method_codec.h>
#include <flutter/method_result_functions.h>
#include <winsparkle.h>
#include <string>
#include <ctime>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
std::string StringArg(const Map& args, const char* key) {
  auto found = args.find(Value(key));
  if (found == args.end()) return "";
  auto value = std::get_if<std::string>(&found->second);
  return value ? *value : "";
}
bool BoolArg(const Map& args, const char* key, bool fallback = false) {
  auto found = args.find(Value(key));
  if (found == args.end()) return fallback;
  auto value = std::get_if<bool>(&found->second);
  return value ? *value : fallback;
}
#define LOCKORA_WIDE_INNER(value) L##value
#define LOCKORA_WIDE(value) LOCKORA_WIDE_INNER(value)
}

LockoraUpdater* LockoraUpdater::instance_ = nullptr;

LockoraUpdater::LockoraUpdater(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window), stopping_(CreateEvent(nullptr, TRUE, FALSE, nullptr)) {
  instance_ = this;
  channel_ = std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "me.tbtparent.lockora/updater", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto args_ptr = call.arguments() ? std::get_if<Map>(call.arguments()) : nullptr;
    const Map empty;
    const auto& args = args_ptr ? *args_ptr : empty;
    if (call.method_name() == "configure") {
      if (configured_) { result->Success(Value(true)); return; }
      const auto feed = StringArg(args, "feedURL");
      const auto key = StringArg(args, "publicKey");
      if (feed.rfind("https://", 0) != 0 || feed.size() <= 8 ||
          win_sparkle_set_eddsa_public_key(key.c_str()) != 1) {
        Status("unconfigured", "更新源或签名公钥尚未配置。");
        result->Error("unconfigured", "更新源或签名公钥尚未配置。"); return;
      }
      win_sparkle_set_appcast_url(feed.c_str());
      win_sparkle_set_app_details(L"com.example", L"Lockora", LOCKORA_WIDE(FLUTTER_VERSION));
      const auto build = std::to_wstring(FLUTTER_VERSION_MAJOR) + L"." +
          std::to_wstring(FLUTTER_VERSION_MINOR) + L"." + std::to_wstring(FLUTTER_VERSION_PATCH) +
          L"." + std::to_wstring(FLUTTER_VERSION_BUILD);
      win_sparkle_set_app_build_version(build.c_str());
      win_sparkle_set_can_shutdown_callback(CanShutdown);
      win_sparkle_set_shutdown_request_callback(Shutdown);
      win_sparkle_set_error_callback([]() { PostStatus(1); });
      win_sparkle_set_did_find_update_callback([]() { PostStatus(2); });
      win_sparkle_set_did_not_find_update_callback([]() { PostStatus(3); });
      win_sparkle_set_update_cancelled_callback([]() { PostStatus(4); });
      win_sparkle_set_update_dismissed_callback([]() { PostStatus(4); });
      win_sparkle_set_update_check_interval(86400);
      win_sparkle_set_automatic_check_for_updates(BoolArg(args, "automaticChecks", true));
      configured_ = true;
      Status("idle");
      win_sparkle_init();
    } else if (call.method_name() == "setCanInstall") {
      can_install_.store(BoolArg(args, "allowed"));
    } else if (call.method_name() == "setAutomaticChecks") {
      if (configured_) win_sparkle_set_automatic_check_for_updates(BoolArg(args, "enabled"));
    } else if (call.method_name() == "checkForUpdates") {
      if (!configured_) { result->Error("unconfigured", "更新尚未配置。"); return; }
      if (BoolArg(args, "background")) {
        const auto last = win_sparkle_get_last_check_time();
        if (win_sparkle_get_automatic_check_for_updates() &&
            (last < 0 || std::time(nullptr) - last >= 86400)) {
          Status("checking"); win_sparkle_check_update_without_ui();
        } else { Status("idle"); }
      } else { Status("checking"); win_sparkle_check_update_with_ui(); }
    } else { result->NotImplemented(); return; }
    result->Success(Value(true));
  });
}

LockoraUpdater::~LockoraUpdater() {
  SetEvent(stopping_);
  if (configured_) win_sparkle_cleanup();
  instance_ = nullptr;
  // Discard any preparation message queued before cleanup joined the worker.
  MSG message;
  while (PeekMessage(&message, window_, kPrepareMessage, kPrepareMessage, PM_REMOVE)) {
    delete reinterpret_cast<std::shared_ptr<Preparation>*>(message.lParam);
  }
  CloseHandle(stopping_);
}

void LockoraUpdater::Status(const char* status, const char* message) {
  Map args{{Value("status"), Value(status)}};
  if (message) args[Value("message")] = Value(message);
  channel_->InvokeMethod("updateStatus", std::make_unique<Value>(args));
}
void LockoraUpdater::PostStatus(int status) {
  if (instance_) PostMessage(instance_->window_, kStatusMessage, status, 0);
}
int __cdecl LockoraUpdater::CanShutdown() {
  auto self = instance_;
  if (!self || !self->can_install_.load()) { PostStatus(5); return 0; }
  auto request = std::make_shared<Preparation>();
  auto posted = new std::shared_ptr<Preparation>(request);
  if (!PostMessage(self->window_, kPrepareMessage, 0, reinterpret_cast<LPARAM>(posted))) {
    delete posted; return 0;
  }
  HANDLE events[] = {self->stopping_, request->event};
  const auto wait = WaitForMultipleObjects(2, events, FALSE, 30000);
  const bool authorized = wait == WAIT_OBJECT_0 + 1 && request->allowed.load();
  if (!authorized) {
    request->expired.store(true);
    if (request->completed.load()) PostStatus(6);
  }
  // Dart sets availability false while locking and stopping the server.
  // The current, unexpired preparation result authorizes installation.
  return authorized;
}
void __cdecl LockoraUpdater::Shutdown() {
  if (instance_) PostMessage(instance_->window_, kShutdownMessage, 0, 0);
}
bool LockoraUpdater::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == kStatusMessage) {
    // WinSparkle can report cancellation after a timed-out shutdown request.
    // Recover Dart only after its in-flight preparation has actually completed.
    if (active_preparation_ && !active_preparation_->completed.load()) return true;
    switch (wparam) {
      case 1: Status("error", "检查或安装更新失败，请重试。"); break;
      case 2: Status("available"); break;
      case 3: Status("upToDate"); break;
      case 4: Status("idle"); break;
      case 6: Status("error", "更新安装准备未完成，请重试。"); break;
      case 5: Status("blocked", "请先完成正在进行的编辑或保存，再安装更新。"); break;
    }
    return true;
  }
  if (message == kPrepareMessage) {
    std::unique_ptr<std::shared_ptr<Preparation>> posted(
        reinterpret_cast<std::shared_ptr<Preparation>*>(lparam));
    auto request = *posted;
    if (request->expired.load() || !can_install_.load()) {
      request->Complete(false);
      Status("blocked", "请先完成正在进行的编辑或保存，再安装更新。");
      return true;
    }
    active_preparation_ = request;
    channel_->InvokeMethod("prepareInstall", nullptr,
        std::make_unique<flutter::MethodResultFunctions<Value>>(
          [request](const Value* value) {
            const auto allowed = value ? std::get_if<bool>(value) : nullptr;
            const bool prepared = allowed && *allowed;
            if (!request->Complete(prepared)) PostStatus(6);
            else if (!prepared) PostStatus(5);
          },
          [request](const std::string&, const std::string&, const Value*) { request->Complete(false); PostStatus(6); },
          [request]() { request->Complete(false); PostStatus(6); }));
    return true;
  }
  if (message == kShutdownMessage) {
    Status("installing");
    PostMessage(window_, WM_CLOSE, 0, 0);
    return true;
  }
  return false;
}
