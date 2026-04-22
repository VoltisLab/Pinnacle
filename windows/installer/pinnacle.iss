; Inno Setup installer script for Pinnacle Transfer (Windows x64).
;
; Build the Flutter release bundle first:
;   flutter build windows --release
; Then compile this script with Inno Setup 6 (ISCC.exe):
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" windows\installer\pinnacle.iss
; Output: windows\installer\Output\PinnacleTransferSetup-<version>.exe

#define MyAppName         "Pinnacle"
#define MyAppProduct      "Pinnacle Transfer"
#define MyAppVersion      "1.0.0"
#define MyAppPublisher    "Voltis Labs"
#define MyAppExeName      "Pinnacle.exe"
#define MyAppURL          "https://voltislabs.uk"
#define MyAppSupportURL   "https://voltislabs.uk/support"
#define MyAppUpdatesURL   "https://voltislabs.uk/pinnacle"
#define MyAppPrivacyURL   "https://voltislabs.uk/privacy"
#define MyAppContact      "hello@voltislabs.uk"
#define MyAppCopyright    "Copyright (C) 2026 Voltis Labs Ltd. All rights reserved."

; Path (relative to this .iss file) to the Flutter Windows release bundle.
#define SourceBundle     "..\..\build\windows\x64\runner\Release"

[Setup]
; Uniquely identifies the app for upgrades / uninstall. Do NOT change
; once it has been shipped to users — a new GUID would create a second
; install entry instead of upgrading in place.
AppId={{B6E7C5A8-4D2F-4F5C-8B9B-5E5E2F7B4F11}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppProduct} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppSupportURL}
AppUpdatesURL={#MyAppUpdatesURL}
AppContact={#MyAppContact}
AppCopyright={#MyAppCopyright}
AppComments=Wireless peer-to-peer file transfer for devices on the same Wi-Fi. Files never touch our servers.
DefaultDirName={autopf}\{#MyAppProduct}
DefaultGroupName={#MyAppProduct}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=PinnacleTransferSetup-{#MyAppVersion}
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
UninstallDisplayName={#MyAppProduct}
UninstallDisplayIcon={app}\{#MyAppExeName}
MinVersion=10.0.17763
; About-dialog metadata that Windows surfaces in "Apps & features" and
; file properties. Keeping Product / Description consistent with the
; publisher's brand makes it obvious this is a Voltis Labs build.
VersionInfoCompany={#MyAppPublisher}
VersionInfoProductName={#MyAppProduct}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
VersionInfoDescription={#MyAppProduct} Setup
VersionInfoCopyright={#MyAppCopyright}
; Friendly info text shown in the "Ready to install" step.
SetupIconFile=..\runner\resources\app_icon.ico
; No digital signature yet; builders can add SignTool= here once the
; code-signing cert is provisioned.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
; Nicer headings on the first / last wizard pages.
WelcomeLabel1=Welcome to the %1 Setup Wizard
WelcomeLabel2=This will install [name/ver] on your computer.%n%nBy %1 — voltislabs.uk
FinishedHeadingLabel=Pinnacle Transfer is ready
FinishedLabel=Click Finish to close Setup and launch %1. Thanks for trying a Voltis Labs app.

[CustomMessages]
LaunchProgram=Launch %1 now

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Ship the entire Flutter release bundle (exe + DLLs + data/ assets).
Source: "{#SourceBundle}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppProduct}"; Filename: "{app}\{#MyAppExeName}"; Comment: "Wireless file transfer by Voltis Labs"
Name: "{autodesktop}\{#MyAppProduct}"; Filename: "{app}\{#MyAppExeName}"; Comment: "Wireless file transfer by Voltis Labs"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppProduct, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
Filename: "{#MyAppPrivacyURL}"; Description: "View the privacy policy online"; Flags: shellexec postinstall skipifsilent unchecked
