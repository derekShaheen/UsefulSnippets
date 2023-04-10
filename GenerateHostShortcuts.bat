@echo off
setlocal enabledelayedexpansion

set HOSTS_FILE=%TEMP%\hosts.txt
echo. > %HOSTS_FILE%

:INPUT_LOOP
set "HOSTNAME="
set /p "HOSTNAME=Enter a host name (or press Enter to finish): "
if not defined HOSTNAME goto SET_OUTPUT_DIR
echo %HOSTNAME%>>%HOSTS_FILE%
goto INPUT_LOOP

:SET_OUTPUT_DIR
set /p "OUTPUT_DIR=Enter an output directory or press Enter to use the Desktop: "
if "%OUTPUT_DIR%"=="" set OUTPUT_DIR=%USERPROFILE%\Desktop
goto CREATE_SHORTCUTS

:CREATE_SHORTCUTS
for /F "usebackq delims=" %%h in (%HOSTS_FILE%) do (
    if not "%%h"=="" (
        for /F "tokens=1,2 delims=." %%a in ("%%h") do set "FIRST_SEGMENT=%%a" & set "SECOND_SEGMENT=%%b"
        set "PREFIX="
        if "!FIRST_SEGMENT:~-1!"=="C" set PREFIX=DEV
        if "!FIRST_SEGMENT:~-1!"=="T" set PREFIX=TEST
        if "!FIRST_SEGMENT:~-1!"=="P" set PREFIX=PROD
        
        if "!FIRST_SEGMENT:ADV=!" NEQ "!FIRST_SEGMENT!" (
            set "MIDDLE=!PREFIX!APP"
        ) else if "!FIRST_SEGMENT:DB=!" NEQ "!FIRST_SEGMENT!" (
            set "MIDDLE=!PREFIX!SQL"
        ) else if "!FIRST_SEGMENT:WEB=!" NEQ "!FIRST_SEGMENT!" (
            set "MIDDLE=!PREFIX!WEB"
        ) else (
            set "MIDDLE=!PREFIX!_!FIRST_SEGMENT!"
        )
        
        if defined MIDDLE (
            set "SHORTCUT_NAME=!MIDDLE!_!SECOND_SEGMENT!.lnk"
            if "!SECOND_SEGMENT!"=="" set "SHORTCUT_NAME=!MIDDLE!.lnk"
            set "SHORTCUT_TARGET=\\%%h"
            call :CREATE_SHORTCUT "%OUTPUT_DIR%" "!SHORTCUT_NAME!" "!SHORTCUT_TARGET!"
        )
    )
)
del %HOSTS_FILE%
echo Shortcuts created in the output directory!
goto END

:CREATE_SHORTCUT
set "FOLDER=%~1"
set "SHORTCUT_NAME=%~2"
set "SHORTCUT_TARGET=%~3"
echo Creating shortcut: %SHORTCUT_NAME%
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%TEMP%\createShortcut.vbs"
echo sLinkFile = "%FOLDER%\%SHORTCUT_NAME%" >> "%TEMP%\createShortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%TEMP%\createShortcut.vbs"
echo oLink.TargetPath = """%SHORTCUT_TARGET%""" >> "%TEMP%\createShortcut.vbs"
echo oLink.Save >> "%TEMP%\createShortcut.vbs"
cscript /nologo "%TEMP%\createShortcut.vbs"
del "%TEMP%\createShortcut.vbs"
goto :eof

:END
