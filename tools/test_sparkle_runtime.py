"""Load the shipped Sparkle framework with release signing flags, without launching Lockora."""
from pathlib import Path
import subprocess
import sys
import tempfile

app = Path(sys.argv[1]).resolve()
frameworks = app / 'Contents/Frameworks'
metadata = subprocess.run(['codesign', '-dv', '--verbose=4', str(app)], capture_output=True, check=True).stderr.decode()
entitlements = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], capture_output=True, check=True).stdout
with tempfile.TemporaryDirectory(prefix='lockora-sparkle-load-') as temporary:
    root = Path(temporary)
    source = root / 'main.m'
    source.write_text('#import <Foundation/Foundation.h>\n@interface SPUUpdater : NSObject @end\nint main(void) { @autoreleasepool { NSLog(@"Sparkle loaded: %@", NSStringFromClass([SPUUpdater class])); } return 0; }\n')
    binary = root / 'load-sparkle'
    subprocess.run(['clang', '-fobjc-arc', str(source), '-framework', 'Foundation',
                    '-F' + str(frameworks), '-framework', 'Sparkle',
                    '-Wl,-rpath,' + str(frameworks), '-o', str(binary)], check=True)
    signing = ['codesign', '--force', '--sign', '-']
    if 'runtime)' in metadata:
        signing += ['--options', 'runtime']
    if b'<plist' in entitlements:
        target = root / 'entitlements.plist'
        target.write_bytes(entitlements)
        signing += ['--entitlements', str(target)]
    subprocess.run(signing + [str(binary)], check=True, capture_output=True)
    subprocess.run([str(binary)], check=True)
print('Release Sparkle runtime load verified; application preferences were not accessed')
