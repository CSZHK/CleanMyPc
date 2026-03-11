package main

import (
	"context"
	"errors"
	"fmt"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/shirou/gopsutil/v4/disk"
)

var skipDiskMounts = map[string]bool{
	"/System/Volumes/VM":       true,
	"/System/Volumes/Preboot":  true,
	"/System/Volumes/Update":   true,
	"/System/Volumes/xarts":    true,
	"/System/Volumes/Hardware": true,
	"/System/Volumes/Data":     true,
	"/dev":                     true,
}

var skipDiskFSTypes = map[string]bool{
	"afpfs":   true,
	"autofs":  true,
	"cifs":    true,
	"devfs":   true,
	"fuse":    true,
	"fuseblk": true,
	"fusefs":  true,
	"macfuse": true,
	"nfs":     true,
	"osxfuse": true,
	"procfs":  true,
	"smbfs":   true,
	"tmpfs":   true,
	"webdav":  true,
}

func collectDisks() ([]DiskStatus, error) {
	partitions, err := disk.Partitions(false)
	if err != nil {
		return nil, err
	}

	var (
		disks      []DiskStatus
		seenDevice = make(map[string]bool)
		seenVolume = make(map[string]bool)
	)
	for _, part := range partitions {
		if shouldSkipDiskPartition(part) {
			continue
		}
		baseDevice := baseDeviceName(part.Device)
		if baseDevice == "" {
			baseDevice = part.Device
		}
		if seenDevice[baseDevice] {
			continue
		}
		usage, err := disk.Usage(part.Mountpoint)
		if err != nil || usage.Total == 0 {
			continue
		}
		// Skip <1GB volumes.
		if usage.Total < 1<<30 {
			continue
		}
		// Use size-based dedupe key for shared pools.
		volKey := fmt.Sprintf("%s:%d", part.Fstype, usage.Total)
		if seenVolume[volKey] {
			continue
		}
		disks = append(disks, DiskStatus{
			Mount:       part.Mountpoint,
			Device:      part.Device,
			Used:        usage.Used,
			Total:       usage.Total,
			UsedPercent: usage.UsedPercent,
			Fstype:      part.Fstype,
		})
		seenDevice[baseDevice] = true
		seenVolume[volKey] = true
	}

	annotateDiskTypes(disks)

	sort.Slice(disks, func(i, j int) bool {
		// First, prefer internal disks over external
		if disks[i].External != disks[j].External {
			return !disks[i].External
		}
		// Then sort by size (largest first)
		return disks[i].Total > disks[j].Total
	})

	if len(disks) > 3 {
		disks = disks[:3]
	}

	return disks, nil
}

func shouldSkipDiskPartition(part disk.PartitionStat) bool {
	if strings.HasPrefix(part.Device, "/dev/loop") {
		return true
	}
	if skipDiskMounts[part.Mountpoint] {
		return true
	}
	if strings.HasPrefix(part.Mountpoint, "/System/Volumes/") {
		return true
	}
	if strings.HasPrefix(part.Mountpoint, "/private/") {
		return true
	}

	fstype := strings.ToLower(part.Fstype)
	if skipDiskFSTypes[fstype] || strings.Contains(fstype, "fuse") {
		return true
	}

	// On macOS, local disks should come from /dev. This filters sshfs/macFUSE-style
	// mounts that can mirror the root volume and show up as duplicate internal disks.
	if runtime.GOOS == "darwin" && part.Device != "" && !strings.HasPrefix(part.Device, "/dev/") {
		return true
	}

	return false
}

var (
	// External disk cache.
	lastDiskCacheAt time.Time
	diskTypeCache   = make(map[string]bool)
	diskCacheTTL    = 2 * time.Minute
)

func annotateDiskTypes(disks []DiskStatus) {
	if len(disks) == 0 || runtime.GOOS != "darwin" || !commandExists("diskutil") {
		return
	}

	now := time.Now()
	// Clear stale cache.
	if now.Sub(lastDiskCacheAt) > diskCacheTTL {
		diskTypeCache = make(map[string]bool)
		lastDiskCacheAt = now
	}

	for i := range disks {
		base := baseDeviceName(disks[i].Device)
		if base == "" {
			base = disks[i].Device
		}

		if val, ok := diskTypeCache[base]; ok {
			disks[i].External = val
			continue
		}

		external, err := isExternalDisk(base)
		if err != nil {
			external = strings.HasPrefix(disks[i].Mount, "/Volumes/")
		}
		disks[i].External = external
		diskTypeCache[base] = external
	}
}

func baseDeviceName(device string) string {
	device = strings.TrimPrefix(device, "/dev/")
	if !strings.HasPrefix(device, "disk") {
		return device
	}
	for i := 4; i < len(device); i++ {
		if device[i] == 's' {
			return device[:i]
		}
	}
	return device
}

func isExternalDisk(device string) (bool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	out, err := runCmd(ctx, "diskutil", "info", device)
	if err != nil {
		return false, err
	}
	var (
		found    bool
		external bool
	)
	for line := range strings.Lines(out) {
		trim := strings.TrimSpace(line)
		if strings.HasPrefix(trim, "Internal:") {
			found = true
			external = strings.Contains(trim, "No")
			break
		}
		if strings.HasPrefix(trim, "Device Location:") {
			found = true
			external = strings.Contains(trim, "External")
		}
	}
	if !found {
		return false, errors.New("diskutil info missing Internal field")
	}
	return external, nil
}

func (c *Collector) collectDiskIO(now time.Time) DiskIOStatus {
	counters, err := disk.IOCounters()
	if err != nil || len(counters) == 0 {
		return DiskIOStatus{}
	}

	var total disk.IOCountersStat
	for _, v := range counters {
		total.ReadBytes += v.ReadBytes
		total.WriteBytes += v.WriteBytes
	}

	if c.lastDiskAt.IsZero() {
		c.prevDiskIO = total
		c.lastDiskAt = now
		return DiskIOStatus{}
	}

	elapsed := now.Sub(c.lastDiskAt).Seconds()
	if elapsed <= 0 {
		elapsed = 1
	}

	readRate := float64(total.ReadBytes-c.prevDiskIO.ReadBytes) / 1024 / 1024 / elapsed
	writeRate := float64(total.WriteBytes-c.prevDiskIO.WriteBytes) / 1024 / 1024 / elapsed

	c.prevDiskIO = total
	c.lastDiskAt = now

	if readRate < 0 {
		readRate = 0
	}
	if writeRate < 0 {
		writeRate = 0
	}

	return DiskIOStatus{ReadRate: readRate, WriteRate: writeRate}
}
