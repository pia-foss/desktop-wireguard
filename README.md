# wireguard-build

This repository contains scripts and submodules used to build binary WireGuard®  assets for distrubtion with the Private Internet Access Desktop Application.

### Linux

```
$ scripts/build-linux.sh
-> Creates out/artifacts/wireguard-go
```

### Mac

* Install Go language support from https://golang.org

```
$ scripts/build-macos.sh
-> Creates out/artifacts/wireguard-go
```

### Windows

The Windows desktop application requires two components built using this repository:

* `wintun.msi` - an installer for the WinTUN driver required by WireGuard®.
* `wgservice.exe` - a wrapper based on `wireguard-windows/embeddable-dll-service` intended to be installed and run as a Windows Service.

To build the windows dependencies, you will have to be running Windows 10. Additionally, code signing requires:
 * A SHA256 code signing cert (does not need to be an EV cert)
 * signtool.exe to sign MSI, build script will find it from Windows SDK by default

```
> set PIA_SIGN_SHA256_CERT=<cert_thumbprint>
> scripts\build-windows.bat <...path...>\pia_desktop pia
```

#### Disclaimer

All product and company names are trademarks™ or registered® trademarks of their respective holders. Use of them does not imply any affiliation with or endorsement by them.   

WireGuard® is a trademark of Jason A. Donenfeld, an individual