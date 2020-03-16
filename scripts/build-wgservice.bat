@echo off

rem This script was originally based on: https://git.zx2c4.com/wireguard-windows/tree/build.bat
rem SPDX-License-Identifier: MIT
rem Copyright (C) 2019 WireGuard LLC. All Rights Reserved.
rem Modifications Copyright (C) 2020 Private Internet Access, Inc., and released under the MIT License. 

setlocal
set BUILDDIR=%~dp0..
set PATHEXT=.exe
cd /d %BUILDDIR% || exit /b 1

REM clear existing wgservice, thus preventing any git issues
rmdir /s /q %BUILDDIR%\wireguard-windows\wgservice 2> NUL

git submodule init
git submodule update

mkdir out
mkdir out\artifacts
mkdir out\artifacts\x86
mkdir out\artifacts\x86_64


REM path
set DEPS=%BUILDDIR%\.deps\

REM path to embeddable dll service folder
set EDSPATH=%BUILDDIR%\wgservice\

set ARTIFACTSPATH=%BUILDDIR%\out\artifacts

if exist %DEPS%\prepared goto :build
:installdeps
	rmdir /s /q %DEPS% 2> NUL
	mkdir %DEPS% || goto :error
	cd %DEPS% || goto :error
	call :setup go.zip  || goto :error
	rem Mirror of https://musl.cc/i686-w64-mingw32-native.zip
	call :download mingw-x86.zip https://download.wireguard.com/windows-toolchain/distfiles/i686-w64-mingw32-native-20190903.zip dfb297cc86c4a4c12eedaeb0a89dff2e1cfa9afacfb9c32690dd23ca7726560a || goto :error
	rem Mirror of https://musl.cc/x86_64-w64-mingw32-native.zip
	call :download mingw-amd64.zip https://download.wireguard.com/windows-toolchain/distfiles/x86_64-w64-mingw32-native-20190903.zip 15cf5596ece5394be0d71c22f586ef252e0390689ef6526f990a262f772aecf8 || goto :error
	copy /y NUL prepared > NUL || goto :error
	cd .. || goto :error

:build
  rmdir /s /q %BUILDDIR%\wireguard-windows\wgservice\ 2> NUL
  mkdir %BUILDDIR%\wireguard-windows\wgservice\
  copy %BUILDDIR%\wgservice\wgservice.go %BUILDDIR%\wireguard-windows\wgservice\wgservice.go

  cd %BUILDDIR%\wireguard-windows\wgservice\
  set GOOS=windows
	set GOPATH=%DEPS%\gopath
	set GOROOT=%DEPS%\go
	set CGO_ENABLED=1
	set CGO_CFLAGS=-O3 -Wall -Wno-unused-function -Wno-switch -std=gnu11 -DWINVER=0x0601
	set CGO_LDFLAGS=-Wl,--dynamicbase -Wl,--nxcompat -Wl,--export-all-symbols
	call :build_plat x86 i686 386 || goto :error
	set CGO_LDFLAGS=%CGO_LDFLAGS% -Wl,--high-entropy-va
	call :build_plat x86_64 x86_64 amd64 || goto :error
  goto :success

:download
	echo [+] Downloading %1
	curl -#fLo %1 %2 || exit /b 1
	echo [+] Verifying %1
	for /f %%a in ('CertUtil -hashfile %1 SHA256 ^| findstr /r "^[0-9a-f]*$"') do if not "%%a"=="%~3" exit /b 1
	echo [+] Extracting %1
	tar -xf %1 %~4 || exit /b 1
	echo [+] Cleaning up %1
	del %1 || exit /b 1
	goto :eof

:build_plat
  set PATH=%DEPS%\go\bin;%DEPS%\%~2-w64-mingw32-native\bin;%PATH
	set CC=%~2-w64-mingw32-gcc
	set GOARCH=%~3
	mkdir %1 >NUL 2>&1
	echo [+] Building library %1
	go build -ldflags="-w -s" -v -o "../../out/artifacts/%~1/wgservice.exe" || exit /b 1
	goto :eof
  
:success
	echo [+] Success. 
	exit /b 0

:setup
	echo [+] Extracting %1
	"C:\Program Files\7-Zip\7z.exe" x "%BUILDDIR%\deps\win\%1" || exit /b 1
	goto :eof

:error
	echo [-] Failed with error #%errorlevel%.
	cmd /c exit %errorlevel%
