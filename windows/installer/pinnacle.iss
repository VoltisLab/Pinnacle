; Inno Setup installer script for Pinnacle (Windows x64)
; Build the Flutter release bundle first:
;   flutter build windows --release
; Then compile this script with Inno Setup 6 (ISCC.exe):
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer\pinnacle.iss
; Output: windows\installer\Output\PinnacleSetup-<version>.exe

#define MyAppName       "Pinnacle"
#define MyAppVersion    "1.0.0"
#define MyAppPublisher  "Pinnacle"
#define MyAppExeName    "Pinnacle.exe"
#define MyAppURL        "https://github.com/VoltisLab/Pinnacle"

; Path (relative to this .iss file) to the Flutter Windows release bundle.
#define SourceBundle    "..\..\build\windows\x64\runner\Release"

[Setup]
; NOTE: this AppId uniquely identifies the app for upgrades/uninstall; do NOT
; change it once users have installed the app.
AppId={{B6E7C5A8-4D2F-4F5C-8B9B-5E5E2F7B4F11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=PinnacleSetup-{#MyAppVersion}
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Ship the entire Flutter release bundle (exe + DLLs + data/ assets).
Source: "{#SourceBundle}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
