; Per-user upgrades preserve all preferences, libraries and cloud files.
#ifndef AppVersion
  #error AppVersion must be passed from pubspec.yaml
#endif
#ifndef BuildNumber
  #error BuildNumber must be passed from pubspec.yaml
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputPath
  #define OutputPath "..\..\dist"
#endif
[Setup]
AppId={{4C4EA20E-19D1-4D56-872A-73BB330C59DB}
AppName=Lockora
AppVersion={#AppVersion}
AppVerName=Lockora {#AppVersion}
VersionInfoVersion={#AppVersion}.{#BuildNumber}
AppPublisher=tbtparent
DefaultDirName={localappdata}\Programs\Lockora
DefaultGroupName=Lockora
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputPath}
OutputBaseFilename=Lockora-{#AppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\Lockora.exe
CloseApplications=yes
RestartApplications=no
SetupMutex=LockoraSetup
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\Lockora"; Filename: "{app}\Lockora.exe"
[Run]
Filename: "{app}\Lockora.exe"; Description: "Launch Lockora"; Flags: nowait postinstall
; No [UninstallDelete] entries: user settings and vaults must remain intact.
