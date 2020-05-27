/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2019 WireGuard LLC. All Rights Reserved.
 */

/*
 * This file is derived from wireguard-windows/embeddable-dll-service/main.go
 * Modifications Copyright (C) 2020 Private Internet Access, Inc., and released under the MIT License.
 *
 * The original file has been modified to be built as an executable, and an extra feature to read
 * diagnostic logs was added.
 */

package main

import (
    "C"

    "golang.org/x/sys/windows"

    "golang.zx2c4.com/wireguard/windows/conf"
    "golang.zx2c4.com/wireguard/windows/ringlogger"
    "golang.zx2c4.com/wireguard/windows/tunnel"
    "golang.zx2c4.com/wireguard/tun/wintun"

    "errors"
    "fmt"
    "log"
    "os"
    "path/filepath"
    "io/ioutil"
)

const (
    ExitImproperArgs = -1
    ExitSuccess = 0
    ExitFindError = 1
    ExitFindNotFound = 2
    ExitCleanError = 1
)

func WireGuardTunnelService(confFile string) bool {
    conf.PresetRootDirectory(filepath.Dir(confFile))
    tunnel.UseFixedGUIDInsteadOfDeterministic = true
    err := tunnel.Run(confFile)
    if err != nil {
        log.Printf("Service run error: %v", err)
    }
    return err == nil
}

func WireGuardDumpLogs(confFile string) bool {
    conf.PresetRootDirectory(filepath.Dir(confFile))
    err := ringlogger.DumpTo(os.Stdout, false)
    if err != nil {
        log.Printf("Error dumping logs: %v", err)
    }

    return err == nil
}

func printUsage() {
    log.Printf("Usage:")
    log.Printf("  wgservice.exe [path to conf file]")
    log.Printf("  wgservice.exe [/dumplog] [path to conf file]")
    log.Printf("  wgservice.exe [/cleaninterface] [ifname]")
    log.Printf("  wgservice.exe [/findinterface] [ifname] [luidfile]")
}

const WintunPool = wintun.Pool("WireGuard")

func mainWithRet() int {
    if len(os.Args) < 2 {
        printUsage()
        return ExitImproperArgs
    }

    if len(os.Args) == 2 {
        log.Printf("Running tunnel from file: %s", os.Args[1])
        WireGuardTunnelService(os.Args[1])
        return ExitSuccess
    }

    switch cmd := os.Args[1]; cmd {
        case "/dumplog":
            if len(os.Args) != 3 {
                printUsage()
                return ExitImproperArgs
            }
            log.Printf("Dumping log w/ conf file: %s", os.Args[2])
            WireGuardDumpLogs(os.Args[2])
            return ExitSuccess
        case "/findinterface":
            if len(os.Args) != 4 {
                printUsage()
                return ExitImproperArgs
            }
            itf, err := WintunPool.GetInterface(os.Args[2])
            if err != nil {
                if errors.Is(err, windows.ERROR_OBJECT_NOT_FOUND) {
                    log.Printf("interface not found")
                    return ExitFindNotFound
                }
                log.Printf("error finding interface: %s", err.Error())
                return ExitFindError
            }

            luidStr := fmt.Sprintf("%d", itf.LUID())
            log.Printf("interface: %s", luidStr)

            err = ioutil.WriteFile(os.Args[3], []byte(luidStr), 0600)
            if err != nil {
                log.Printf("error writing file: %s", err.Error())
                return ExitFindError
            }

            return ExitSuccess
        case "/cleaninterface":
            if len(os.Args) != 3 {
                printUsage()
                return ExitImproperArgs
            }
            itf, err := WintunPool.GetInterface(os.Args[2])
            if err != nil {
                if errors.Is(err, windows.ERROR_OBJECT_NOT_FOUND) {
                    fmt.Printf("success: did not exist")
                    return ExitSuccess
                } else {
                    fmt.Printf("error: (finding) %s", err.Error())
                    return ExitCleanError
                }
            } else {
                _, err = itf.DeleteInterface()
                if err != nil {
                    fmt.Printf("error: (deleting) %s", err.Error())
                    return ExitCleanError
                } else {
                    fmt.Printf("success: deleted")
                    return ExitSuccess
                }
            }
        default:
            log.Printf("Unknown argument %s", cmd)
            printUsage()
            return ExitImproperArgs
    }
}

func main() {
    os.Exit(mainWithRet())
}
