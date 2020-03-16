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

	"golang.zx2c4.com/wireguard/windows/conf"
	"golang.zx2c4.com/wireguard/windows/ringlogger"
	"golang.zx2c4.com/wireguard/windows/tunnel"

	"log"
	"os"
	"path/filepath"
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

func main() {
	if len(os.Args) > 2 {
		switch cmd := os.Args[1]; cmd {
		case "/dumplog":
			log.Printf("Dumping log w/ conf file: %s", os.Args[2])
			WireGuardDumpLogs(os.Args[2])
		default:
			log.Printf("Unknown argument %s", cmd)
		}

	} else if len(os.Args) == 2 {
		log.Printf("Running tunnel from file: %s", os.Args[1])
		WireGuardTunnelService(os.Args[1])
	} else {
		log.Printf("Usage: wgservice.exe [path to conf file]")
		log.Printf("Usage: wgservice.exe [/dumplog] [path to conf file]")
	}
}
