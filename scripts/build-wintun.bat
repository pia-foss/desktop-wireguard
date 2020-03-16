rem Copyright (c) 2020 Private Internet Access, Inc.
rem
rem This file is part of the Private Internet Access Desktop Client.
rem
rem The Private Internet Access Desktop Client is free software: you can
rem redistribute it and/or modify it under the terms of the GNU General Public
rem License as published by the Free Software Foundation, either version 3 of
rem the License, or (at your option) any later version.
rem
rem The Private Internet Access Desktop Client is distributed in the hope that
rem it will be useful, but WITHOUT ANY WARRANTY; without even the implied
rem warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
rem GNU General Public License for more details.
rem
rem You should have received a copy of the GNU General Public License
rem along with the Private Internet Access Desktop Client.  If not, see
rem <https://www.gnu.org/licenses/>.

@echo off
setlocal
setlocal EnableDelayedExpansion

pushd %~dp0\..

set ARG_SHOW_HELP=0
set ARG_SHOW_HELP_DETAILS_ONLY=0

:arg_loop
if not "%1"=="" (
    if "%1"=="--help" (
        set ARG_SHOW_HELP=1
    ) else if "%1"=="--help-details" (
        set ARG_SHOW_HELP=1
        set ARG_SHOW_HELP_DETAILS_ONLY=1
    ) else if "%1"=="--" (
        shift
        goto :args_done
    ) else (
        goto :args_done
    )
    shift
    goto :arg_loop
)
:args_done

if "%~2" == "" (
    set ARG_SHOW_HELP=1
)

if %ARG_SHOW_HELP% NEQ 0 (
    if %ARG_SHOW_HELP_DETAILS_ONLY% EQU 0 (
        echo usage: %0 ^<...path_to...^>\pia_desktop ^<brand_code^>
        echo.
    )
    echo Builds the WinTUN MSI distribution for PIA.
    echo.
    echo PIA Desktop path and brand code are used to read brandinfo.json.
    echo.
    echo The WinTUN MSI is **brand-specific** and should only be used for that brand.
    echo ^(Otherwise, different branded builds of PIA would uninstall each others^' WinTUN packages.^)
    echo.
    echo Code signing:
    echo     PIA_SIGN_SHA256_CERT - thumbprint of SHA256 cert used to sign MSI package
    echo     PIA_SIGN_TIMESTAMP - timestamp server for signing ^(default: DigiCert^)
    echo     PIA_SIGNTOOL - Path to signtool.exe ^(default: found in Windows SDK^)
    goto :end
)

set BRAND=%~2
echo Building WinTUN package for brand "%BRAND%"

rem Find signtool
if not defined SIGNTOOL (
  where /Q signtool
  if !errorlevel! equ 0 (
    set SIGNTOOL=signtool
  ) else (
    for /D %%G in ("%PROGRAMFILES(X86)%\Windows Kits\10\bin\10.*") do (
      if exist "%%G\x64\signtool.exe" set "SIGNTOOL=%%G\x64\signtool.exe"
    )
  )
)
if ["%SIGNTOOL%"]==[""] (
  rem If a signing certificate was specified but we couldn't find signtool, quit
  if not [%PIA_SIGN_SHA256_CERT%] == [] (
    echo Error: no signtool executable found
    goto error
  )
)
echo Found signtool executable "%SIGNTOOL%"

if [%PIA_SIGN_TIMESTAMP%] == [] set "PIA_SIGN_TIMESTAMP=http://timestamp.digicert.com"

set BUILD_DIR=.\build\wintun\%BRAND%
set ARTIFACT_DIR=.\out\artifacts
rmdir /Q /S "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

copy /y .\wintun\msi-example\build.bat "%BUILD_DIR%"
copy /y .\wintun\msi-example\exampletun.wxs "%BUILD_DIR%"

set "brandinfo=%~1\brands\%BRAND%\brandinfo.json"

rem Update the version in exampletun.wxs
rem This is the version of the PIA WinTun package.  When updating the WinTUN
rem module, this version must be increased to supersede the old version.
rem
rem The WinTUN tasks in the Windows installer must also be updated with the new
rem version.
rem
rem Windows Installer permits four-part version numbers, but it ignores the
rem fourth part, and PIA does not currently allow a fourth part (in order to
rem treat this as a semantic version).
rem
rem (In principle, updated versions could also add/remove/replace other
rem MSI features, but this package is unlikely to ever include any features
rem besides WinTUN.)
rem
rem The substitution to 1.0.0 isn't a no-op, the original "1.0" results in
rem "1.0.65535" by default.
call :subst_text "%BUILD_DIR%\exampletun.wxs" "Version=^"1.0^"" "Version=^"1.0.0^""

rem Apply branding parameters to exampletun.wxs
call :brand "%brandinfo%" "%BUILD_DIR%\exampletun.wxs" "{{{FIXED 64BIT UUID}}}" "wintunAmd64Product"
call :brand "%brandinfo%" "%BUILD_DIR%\exampletun.wxs" "{{{FIXED 32BIT UUID}}}" "wintunX86Product"
call :brand "%brandinfo%" "%BUILD_DIR%\exampletun.wxs" "Acme Widgets Corporation" "wintunManufacturer"
call :brand "%brandinfo%" "%BUILD_DIR%\exampletun.wxs" "ExampleTun: Acme Widget''s Distribution of Wintun" "wintunDescription"
call :brand "%brandinfo%" "%BUILD_DIR%\exampletun.wxs" "ExampleTun" "wintunProductName"
rem Save the product name for use when signing
set PIA_WINTUN_PRODUCT=%json_val%

rem Set WinTUN version information in build.bat
call :subst_text "%BUILD_DIR%\build.bat" "{{{VERSION}}}" "0.8"
call :subst_text "%BUILD_DIR%\build.bat" "{{{32BIT HASH}}}" "7ff5fcca21be75584fea830a4624ff52305ebb6982c3ec1b294a22b20ee5c1fc"
call :subst_text "%BUILD_DIR%\build.bat" "{{{64BIT HASH}}}" "14e94f3151e425d80fc262b4bb3f351df9d3b3dde5d9cf39aad2e94c39944435"

echo "Building WinTUN packages..."
call "%BUILD_DIR%\build.bat"
if errorlevel 1 (
    echo "WinTUN package build failed"
    goto :error
)

rem Copy artifacts
mkdir "%ARTIFACT_DIR%\x86_64"
mkdir "%ARTIFACT_DIR%\x86"
copy /y "%BUILD_DIR%\dist\exampletun-amd64.msi" "%ARTIFACT_DIR%\x86_64\%BRAND%-wintun.msi"
copy /y "%BUILD_DIR%\dist\exampletun-x86.msi" "%ARTIFACT_DIR%\x86\%BRAND%-wintun.msi"

if not [%PIA_SIGN_SHA256_CERT%] == [] (
    echo "Signing WinTUN packages..."
    "%SIGNTOOL%" sign /fd sha256 /tr "%PIA_SIGN_TIMESTAMP%" /td sha256 /sha1 "%PIA_SIGN_SHA256_CERT%" /d "%PIA_WINTUN_PRODUCT%" "%ARTIFACT_DIR%\x86_64\%BRAND%-wintun.msi" "%ARTIFACT_DIR%\x86\%BRAND%-wintun.msi"
)

goto :funcs_end

rem Get a JSON value from a JSON file, store the result in %json_val%
rem Usage: call :read_json <file_path> <property>
:read_json
for /f "tokens=* USEBACKQ" %%F in (`powershell -Command "(gc '%~1' -Raw | ConvertFrom-Json).%~2"`) do (
    set json_val=%%F
)
exit /b 0

rem Substitute text in a file
rem Usage: call :subst_text <file_path> <old_text> <new_text>
:subst_text
powershell -Command "(gc '%~1' -Raw).Replace('%~2', '%~3') | Set-Content -encoding ASCII -Path '%~1'"
exit /b 0

rem Apply a branding parameter to a file
rem Usage: call :brand <brandinfo.json> <target_file> <old_text> <param_name>
:brand
call :read_json "%~1" "%~4"
call :subst_text "%~2" "%~3" "%json_val%"
exit /b 0

:funcs_end
set rc=0
goto :end
:error
set rc=1
:end
endlocal
popd
exit /b %rc%
