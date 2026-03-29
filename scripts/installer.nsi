!define APPNAME "Large JSON Viewer"
!define COMPANYNAME "A. S. M. Muhiminul Hasan"
!define DESCRIPTION "A high-performance JSON viewer for large files."
!define VERSIONMAJOR 1
!define VERSIONMINOR 0
!define VERSIONBUILD 0
!define HELPURL "https://github.com/muhiminulhasan/LargeJSONViewer"
!define UPDATEURL "https://github.com/muhiminulhasan/LargeJSONViewer"
!define ABOUTURL "https://github.com/muhiminulhasan/LargeJSONViewer"

!define INSTALLSIZE 3512

!ifndef ARCH
    !define ARCH "x64"
!endif

!if "${ARCH}" == "x64"
    !define INSTALL_DIR "$PROGRAMFILES64\${APPNAME}"
    !define OUT_FILE "LargeJSONViewer_x64_Setup.exe"
!else
    !define INSTALL_DIR "$PROGRAMFILES\${APPNAME}"
    !define OUT_FILE "LargeJSONViewer_x86_Setup.exe"
!endif

RequestExecutionLevel admin

InstallDir "${INSTALL_DIR}"

Name "${APPNAME}"
Icon "LargeJSONViewer.ico"
outFile "${OUT_FILE}"

!include LogicLib.nsh
!include "MUI2.nsh"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Section "Install"
    SetOutPath $INSTDIR
    
    File "LargeJSONViewer.exe"
    
    WriteUninstaller "$INSTDIR\uninstall.exe"

    createDirectory "$SMPROGRAMS\${APPNAME}"
    createShortCut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\LargeJSONViewer.exe"
    createShortCut "$SMPROGRAMS\${APPNAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe"

    createShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\LargeJSONViewer.exe"

    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayName" "${APPNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "UninstallString" "$\"$INSTDIR\uninstall.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "QuietUninstallString" "$\"$INSTDIR\uninstall.exe$\" /S"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "InstallLocation" "$\"$INSTDIR$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayIcon" "$\"$INSTDIR\LargeJSONViewer.exe$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "Publisher" "${COMPANYNAME}"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "HelpLink" "$\"${HELPURL}$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "URLUpdateInfo" "$\"${UPDATEURL}$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "URLInfoAbout" "$\"${ABOUTURL}$\""
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayVersion" "${VERSIONMAJOR}.${VERSIONMINOR}.${VERSIONBUILD}"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "VersionMajor" ${VERSIONMAJOR}
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "VersionMinor" ${VERSIONMINOR}
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "NoRepair" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "EstimatedSize" ${INSTALLSIZE}

    ; File Association
    WriteRegStr HKLM "Software\Classes\LargeJSONViewer" "" "JSON File"
    WriteRegStr HKLM "Software\Classes\LargeJSONViewer\DefaultIcon" "" "$\"$INSTDIR\LargeJSONViewer.exe$\",-200"
    WriteRegStr HKLM "Software\Classes\LargeJSONViewer\shell\open\command" "" "$\"$INSTDIR\LargeJSONViewer.exe$\" $\"%1$\""
    
    WriteRegStr HKLM "Software\Classes\.json" "" "LargeJSONViewer"
    WriteRegStr HKLM "Software\Classes\.json\OpenWithProgids" "LargeJSONViewer" ""
    
    ; Refresh shell icons
    System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, i 0, i 0)'
SectionEnd

Section "Uninstall"
    delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
    delete "$SMPROGRAMS\${APPNAME}\Uninstall.lnk"
    rmDir "$SMPROGRAMS\${APPNAME}"
    
    delete "$DESKTOP\${APPNAME}.lnk"

    delete "$INSTDIR\LargeJSONViewer.exe"
    
    delete "$INSTDIR\uninstall.exe"

    rmDir "$INSTDIR"

    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
    
    ; Remove File Association
    DeleteRegKey HKLM "Software\Classes\LargeJSONViewer"
    DeleteRegValue HKLM "Software\Classes\.json\OpenWithProgids" "LargeJSONViewer"
    
    ; Optional: If we were the default handler, we should probably remove ourselves from .json default
    ; Note: It's safer to only remove our specific OpenWithProgids value and our ProgID key.
    
    ; Refresh shell icons
    System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, i 0, i 0)'
SectionEnd
