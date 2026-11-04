"""Test production WinSparkle preparation state without a Windows runtime."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
sdk = os.environ.get('FLUTTER_ROOT')
if not sdk:
    config = (root / 'macos/Flutter/ephemeral/Flutter-Generated.xcconfig').read_text()
    sdk = next(line.split('=', 1)[1] for line in config.splitlines() if line.startswith('FLUTTER_ROOT='))
with tempfile.TemporaryDirectory(prefix='lockora-win-authorization-') as directory:
    path = Path(directory)
    (path / 'windows.h').write_text('''#pragma once
#include <cstdint>
using HANDLE=void*; using HWND=void*; using UINT=unsigned;
using WPARAM=uintptr_t; using LPARAM=intptr_t;
#define TRUE 1
#define FALSE 0
#define WM_APP 32768
inline HANDLE CreateEvent(void*, int, int, void*) { return reinterpret_cast<HANDLE>(1); }
inline int CloseHandle(HANDLE) { return 1; }
inline int SetEvent(HANDLE) { return 1; }
''')
    (path / 'main.cpp').write_text('''#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <atomic>
#include <memory>
#include <cassert>
#define private public
#include "lockora_updater.h"
#undef private
int main() {
  LockoraUpdater::Preparation success;
  bool availability = true;
  assert(availability);
  availability = false; // Dart locks/stops the server before replying true.
  success.Complete(true);
  assert(!availability && success.allowed.load());
  LockoraUpdater::Preparation rejected;
  rejected.Complete(false);
  assert(!rejected.allowed.load());
  LockoraUpdater::Preparation expired;
  expired.expired.store(true);
  expired.Complete(true);
  assert(!expired.allowed.load());
  LockoraUpdater::Preparation next;
  expired.Complete(true);
  assert(!next.allowed.load());
  next.Complete(true);
  assert(next.allowed.load());
}
''')
    include = Path(sdk) / 'engine/src/flutter/shell/platform/common/client_wrapper/include'
    subprocess.run(['clang++', '-std=c++17', '-D__cdecl=', '-Wall', '-Wextra', '-Werror',
                    '-I' + str(path), '-I' + str(include), '-I' + str(root / 'windows/runner'),
                    str(path / 'main.cpp'), '-o', str(path / 'tests')], check=True)
    subprocess.run([str(path / 'tests')], check=True)
    print('Windows preparation authorization: 5 scenarios passed (Win32 event calls stubbed)')
