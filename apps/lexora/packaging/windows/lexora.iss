; Lexora Windows installer. The postinstall entry is intentionally checked
; by default so users can launch Lexora as soon as setup finishes.
#ifndef AppVersion
  #define AppVersion "1.1.2"
#endif
#ifndef SourceDir
  #define SourceDir "build/windows/x64/runner/Release"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "lexora-windows-v1.1.2-setup"
#endif

[Setup]
AppId={{B0C4A6B3-6E9A-4F84-8A5B-1E0A00000101}}
AppName=Lexora
AppVersion={#AppVersion}
AppPublisher=Lexora
AppPublisherURL=https://lexora.12323456.xyz
AppSupportURL=https://github.com/xiaozhangwangxue/lexora
DefaultDirName={autopf}\Lexora
DefaultGroupName=Lexora
DisableProgramGroupPage=yes
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\lexora.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Lexora"; Filename: "{app}\lexora.exe"
Name: "{autodesktop}\Lexora"; Filename: "{app}\lexora.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\lexora.exe"; Description: "{cm:LaunchProgram,Lexora}"; Flags: nowait postinstall skipifsilent
