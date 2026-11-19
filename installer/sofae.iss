; Instalador do Sofae para Windows (Inno Setup 6).
; Gerado no CI pelo .github/workflows/sofae-windows.yml:
;   ISCC /DSourceDir=<pasta do app> /DIconFile=<.ico> /DAppVersion=1.0.0+N /DOutputDir=<saída> installer\sofae.iss
; Instalação por usuário, sem pedir administrador. Saída: Sofae-Setup.exe

#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef IconFile
  #define IconFile "..\windows\runner\resources\app_icon.ico"
#endif
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef OutputDir
  #define OutputDir "Output"
#endif

[Setup]
; AppId fixo: novas versões instalam por cima da anterior (e o desinstalador é o mesmo)
AppId={{71B47D93-C42A-4200-B92B-1EE5A30625CE}
AppName=Sofae
AppVersion={#AppVersion}
AppVerName=Sofae {#AppVersion}
AppPublisher=Akitemtech
DefaultDirName={localappdata}\Programs\Sofae
DefaultGroupName=Sofae
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=Sofae-Setup
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\Sofae.exe
UninstallDisplayName=Sofae
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Tudo o que está na pasta do build: Sofae.exe, DLLs dos plugins, data\ e as DLLs do Visual C++
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Sofae"; Filename: "{app}\Sofae.exe"
Name: "{autodesktop}\Sofae"; Filename: "{app}\Sofae.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Sofae.exe"; Description: "{cm:LaunchProgram,Sofae}"; Flags: nowait postinstall skipifsilent
