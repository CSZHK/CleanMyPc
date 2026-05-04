//go:build darwin

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"sync/atomic"
	"time"
)

type jsonOutput struct {
	Path       string      `json:"path"`
	Entries    []jsonEntry `json:"entries"`
	TotalSize  int64       `json:"total_size"`
	TotalFiles int64       `json:"total_files"`
}

type jsonEntry struct {
	Name            string `json:"name"`
	Path            string `json:"path"`
	Size            int64  `json:"size"`
	IsDir           bool   `json:"is_dir"`
	RiskLevel       string `json:"risk_level,omitempty"`
	StorageCategory string `json:"storage_category,omitempty"`
	LastAccessed    string `json:"last_accessed,omitempty"`
	CreatedDate     string `json:"created_date,omitempty"`
	ExplanationKey  string `json:"explanation_key,omitempty"`
}

func runJSONMode(path string, isOverview bool) {
	result := performScanForJSON(path)

	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(result); err != nil {
		fmt.Fprintf(os.Stderr, "failed to encode JSON: %v\n", err)
		os.Exit(1)
	}
}

func performScanForJSON(path string) jsonOutput {
	var filesScanned, dirsScanned, bytesScanned int64
	currentPath := &atomic.Value{}
	currentPath.Store("")

	items, err := os.ReadDir(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to read directory: %v\n", err)
		os.Exit(1)
	}

	var entries []jsonEntry
	var totalSize int64

	for _, item := range items {
		fullPath := path + "/" + item.Name()
		var size int64
		var lastAccess time.Time
		var createdDate time.Time

		if item.IsDir() {
			size = calculateDirSizeFast(fullPath, &filesScanned, &dirsScanned, &bytesScanned, currentPath)
		} else {
			info, infoErr := item.Info()
			if infoErr == nil {
				size = info.Size()
				lastAccess = getLastAccessTimeFromInfo(info)
				createdDate = getCreationTimeFromInfo(info)
				atomic.AddInt64(&filesScanned, 1)
				atomic.AddInt64(&bytesScanned, size)
			}
		}

		totalSize += size

		risk := riskLevelForPath(fullPath)
		category := categoryForPath(fullPath)

		entry := jsonEntry{
			Name:            item.Name(),
			Path:            fullPath,
			Size:            size,
			IsDir:           item.IsDir(),
			RiskLevel:       string(risk),
			StorageCategory: string(category),
			ExplanationKey:  explanationKeyFor(category, risk),
		}

		if !lastAccess.IsZero() {
			entry.LastAccessed = lastAccess.Format(time.RFC3339)
		}
		if !createdDate.IsZero() {
			entry.CreatedDate = createdDate.Format(time.RFC3339)
		}

		entries = append(entries, entry)
	}

	return jsonOutput{
		Path:       path,
		Entries:    entries,
		TotalSize:  totalSize,
		TotalFiles: atomic.LoadInt64(&filesScanned),
	}
}
