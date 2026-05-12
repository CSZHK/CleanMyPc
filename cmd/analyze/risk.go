package main

import (
	"path/filepath"
	"strings"
)

// RiskLevel represents the safety of deleting a given path.
type RiskLevel string

const (
	RiskSafe     RiskLevel = "safe"     // Safe to delete without concern.
	RiskReview   RiskLevel = "review"   // Should review before deletion.
	RiskAdvanced RiskLevel = "advanced" // Requires advanced knowledge to delete safely.
)

// StorageCategory classifies what kind of storage a path occupies.
type StorageCategory string

const (
	CategorySystemCache       StorageCategory = "systemCache"
	CategoryAppCache          StorageCategory = "appCache"
	CategoryDeveloperArtifact StorageCategory = "developerArtifact"
	CategoryBrowserData       StorageCategory = "browserData"
	CategoryLogFile           StorageCategory = "logFile"
	CategoryDownloadArtifact  StorageCategory = "downloadArtifact"
	CategoryMailAttachment    StorageCategory = "mailAttachment"
	CategoryOldBackup         StorageCategory = "oldBackup"
	CategoryUnknown           StorageCategory = "unknown"
)

// safeDirNames maps directory base names that are safe to delete.
var safeDirNames = map[string]bool{
	// System caches.
	".cache":       true,
	"Caches":       true,
	".tmp":         true,
	".temp":        true,
	"_temp":        true,
	"_tmp":         true,
	"tmp":          true,
	"temp":         true,
	".Trash":       true,
	"$RECYCLE.BIN": true,

	// macOS system artifacts.
	"__MACOSX":                true,
	".DS_Store":               true,
	".Spotlight-V100":         true,
	".fseventsd":              true,
	".DocumentRevisions-V100": true,
	".TemporaryItems":         true,

	// Developer build outputs.
	"build":       true,
	"dist":        true,
	".output":     true,
	"coverage":    true,
	".coverage":   true,
	".nyc_output": true,
	"htmlcov":     true,
	"out":         true,
	"target":      true,
	"DerivedData": true,

	// Developer dependency caches.
	"node_modules":     true,
	"bower_components": true,
	".yarn":            true,
	".pnpm-store":      true,
	"vendor":           true,
	".bundle":          true,
	"Pods":             true,
	"Carthage":         true,

	// Developer tool caches.
	"__pycache__":        true,
	".pytest_cache":      true,
	".mypy_cache":        true,
	".ruff_cache":        true,
	".tox":               true,
	".eggs":              true,
	".ipynb_checkpoints": true,

	// Framework caches.
	".next":         true,
	".nuxt":         true,
	".vite":         true,
	".turbo":        true,
	".parcel-cache": true,
	".nx":           true,
	".angular":      true,
	".svelte-kit":   true,
	".astro":        true,
	".docusaurus":   true,

	// IDE caches.
	".idea": true,
	".vs":   true,

	// Other safe caches.
	".Homebrew":  true,
	".terraform": true,
	".dart_tool": true,
}

// safePathPatterns marks path substrings that indicate safe-to-delete content.
var safePathPatterns = []string{
	"/Library/Caches/",
	"/Library/Logs/",
	"/Library/DiagnosticReports/",
	"/.Trash/",
	"/Library/Saved Application State/",
}

// reviewDirNames maps directory base names that need review before deletion.
var reviewDirNames = map[string]bool{
	// Developer environments (may contain project-specific configurations).
	"venv":       true,
	".venv":      true,
	"virtualenv": true,
	".pyenv":     true,
	".poetry":    true,
	".pip":       true,
	".pipx":      true,
	".rbenv":     true,
	".nvm":       true,
	".rustup":    true,
	".sdkman":    true,
	".deno":      true,
	".bun":       true,

	// Developer build caches (may be expensive to rebuild).
	".gradle": true,
	".m2":     true,
	".ivy2":   true,
	".cargo":  true,
	".build":  true,

	// Package manager caches.
	".npm":      true,
	".composer": true,

	// Application data.
	"Saved Application State": true,
	"Application Scripts":     true,
}

// reviewPathPatterns marks path substrings that indicate review-needed content.
var reviewPathPatterns = []string{
	"/Library/Application Support/",
	"/Library/Preferences/",
	"/Library/Containers/",
	"/Library/Group Containers/",
}

// advancedDirNames maps directory base names that require advanced knowledge to delete.
var advancedDirNames = map[string]bool{
	// System-level directories.
	"System":  true,
	"bin":     true,
	"sbin":    true,
	"etc":     true,
	"var":     true,
	"usr":     true,
	"dev":     true,
	"opt":     true,
	"private": true,
	"cores":   true,

	// Virtualization / containers.
	".docker":     true,
	".containerd": true,

	// Databases (deletion may cause data loss).
	".mysql":    true,
	".postgres": true,
	"mongodb":   true,

	// iCloud.
	"Mobile Documents": true,

	// Version control (critical data).
	".git": true,
	".svn": true,
	".hg":  true,
}

// advancedPathPatterns marks path substrings that indicate advanced-risk content.
var advancedPathPatterns = []string{
	"/Library/LaunchAgents/",
	"/Library/LaunchDaemons/",
	"/Library/PrivilegedHelperTools/",
	"/Library/SystemExtensions/",
	"/Library/Extensions/",
}

// browserDataDirNames marks directories that contain browser data.
var browserDataDirNames = map[string]bool{
	"Safari":              true,
	"Google":              true,
	"Chrome":              true,
	"Chromium":            true,
	"Firefox":             true,
	"BraveSoftware":       true,
	"Microsoft Edge":      true,
	"com.apple.Safari":    true,
	"com.google.Chrome":   true,
	"org.mozilla.firefox": true,
}

// browserPathPatterns marks path substrings that indicate browser data.
var browserPathPatterns = []string{
	"/Library/Safari/",
	"/Library/Application Support/Google/Chrome/",
	"/Library/Application Support/Firefox/",
	"/Library/Application Support/BraveSoftware/",
	"/Library/Application Support/Microsoft Edge/",
	"/Library/Caches/com.apple.Safari/",
	"/Library/Caches/com.google.Chrome/",
	"/Library/Caches/org.mozilla.firefox/",
}

// logFileExtensions marks file extensions that indicate log files.
var logFileExtensions = map[string]bool{
	".log":  true,
	".log.": true,
}

// riskLevelForPath categorizes a filesystem path into a risk level.
func riskLevelForPath(path string) RiskLevel {
	if path == "" {
		return RiskReview
	}

	baseName := filepath.Base(path)

	// Check advanced-risk first (highest risk → most restrictive).
	if advancedDirNames[baseName] {
		return RiskAdvanced
	}
	for _, pattern := range advancedPathPatterns {
		if strings.Contains(path, pattern) {
			return RiskAdvanced
		}
	}

	// Check safe patterns (lowest risk).
	if safeDirNames[baseName] {
		return RiskSafe
	}
	if projectDependencyDirs[baseName] {
		return RiskSafe
	}
	for _, pattern := range safePathPatterns {
		if strings.Contains(path, pattern) {
			return RiskSafe
		}
	}

	// Check review patterns.
	if reviewDirNames[baseName] {
		return RiskReview
	}
	for _, pattern := range reviewPathPatterns {
		if strings.Contains(path, pattern) {
			return RiskReview
		}
	}

	// Check browser data — generally review-level risk.
	if browserDataDirNames[baseName] {
		return RiskReview
	}
	for _, pattern := range browserPathPatterns {
		if strings.Contains(path, pattern) {
			return RiskReview
		}
	}

	// Check foldDirs for known cache/dependency directories.
	if foldDirs[baseName] {
		return RiskSafe
	}

	// Default to review for unrecognized paths.
	return RiskReview
}

// categoryForPath classifies a filesystem path into a storage category.
func categoryForPath(path string) StorageCategory {
	if path == "" {
		return CategoryUnknown
	}

	baseName := filepath.Base(path)

	// Check log files first (extension-based match).
	ext := strings.ToLower(filepath.Ext(path))
	if logFileExtensions[ext] {
		return CategoryLogFile
	}
	// Also match common log naming patterns.
	if strings.Contains(strings.ToLower(baseName), ".log") {
		return CategoryLogFile
	}
	// Check known log path patterns.
	if strings.Contains(path, "/Library/Logs/") || strings.Contains(path, "/var/log/") {
		return CategoryLogFile
	}

	// Browser data.
	for _, pattern := range browserPathPatterns {
		if strings.Contains(path, pattern) {
			return CategoryBrowserData
		}
	}
	if browserDataDirNames[baseName] {
		return CategoryBrowserData
	}
	// Browser cache directories within Library/Caches.
	if strings.Contains(path, "/Library/Caches/") {
		for browser := range browserDataDirNames {
			if strings.Contains(path, browser) {
				return CategoryBrowserData
			}
		}
	}

	// Developer artifacts.
	if projectDependencyDirs[baseName] {
		return CategoryDeveloperArtifact
	}
	if isDeveloperArtifactName(baseName) {
		return CategoryDeveloperArtifact
	}
	// Developer tools configuration directories.
	developerPaths := []string{
		"/.gradle/", "/.m2/", "/.ivy2/", "/.cargo/", "/.rustup/",
		"/.pyenv/", "/.nvm/", "/.sdkman/", "/.poetry/", "/.pip/",
		"/.composer/", "/.bundle/",
	}
	for _, pattern := range developerPaths {
		if strings.Contains(path, pattern) {
			return CategoryDeveloperArtifact
		}
	}

	// Mail attachments.
	if strings.Contains(path, "/Library/Mail/") ||
		strings.Contains(path, "/Library/Containers/com.apple.Mail/") ||
		(strings.Contains(path, "/Library/Group Containers/") && strings.Contains(path, "Mail")) {
		return CategoryMailAttachment
	}

	// Download artifacts.
	if strings.Contains(path, "/Downloads/") ||
		strings.Contains(path, "/Library/Messages/") {
		return CategoryDownloadArtifact
	}

	// Old backups.
	if strings.Contains(path, "Backup") || strings.Contains(path, "backup") ||
		strings.Contains(path, ".backup") || strings.Contains(path, ".bak") ||
		strings.Contains(path, "TimeMachine") || strings.Contains(path, ".MobileBackups") {
		return CategoryOldBackup
	}

	// System cache.
	if strings.Contains(path, "/Library/Caches/") ||
		strings.Contains(path, "/Library/Saved Application State/") ||
		strings.Contains(path, "/Library/DiagnosticReports/") ||
		strings.Contains(path, "/.Trash/") ||
		strings.Contains(path, "/.cache/") ||
		strings.Contains(path, "/Caches/") {
		return CategorySystemCache
	}

	// App cache — application-specific data that isn't strictly a system cache.
	if strings.Contains(path, "/Library/Application Support/") ||
		strings.Contains(path, "/Library/Containers/") ||
		strings.Contains(path, "/Library/Preferences/") {
		return CategoryAppCache
	}

	// Check foldDirs for known cache/dependency directories → system cache.
	if foldDirs[baseName] {
		return CategorySystemCache
	}

	return CategoryUnknown
}

// isDeveloperArtifactName checks if a base name matches common developer artifact patterns.
func isDeveloperArtifactName(name string) bool {
	developerNames := map[string]bool{
		// Language/tool caches.
		"__pycache__":        true,
		".pytest_cache":      true,
		".mypy_cache":        true,
		".ruff_cache":        true,
		".tox":               true,
		".eggs":              true,
		"htmlcov":            true,
		".ipynb_checkpoints": true,

		// Framework caches.
		".next":         true,
		".nuxt":         true,
		".vite":         true,
		".turbo":        true,
		".parcel-cache": true,
		".nx":           true,
		".angular":      true,
		".svelte-kit":   true,
		".astro":        true,
		".docusaurus":   true,
		".solid":        true,

		// Build outputs.
		"build":       true,
		"dist":        true,
		".output":     true,
		"out":         true,
		"target":      true,
		"DerivedData": true,
		".build":      true,

		// IDE.
		".idea":   true,
		".vscode": true,
		".vs":     true,
		".fleet":  true,

		// Mobile dev.
		"Pods":       true,
		"Carthage":   true,
		".dart_tool": true,

		// Other tools.
		".terraform":  true,
		"coverage":    true,
		".coverage":   true,
		".nyc_output": true,
	}

	return developerNames[name]
}

// explanationKeyFor returns a localization key for the explanation template
// based on the storage category and risk level.
// The key format "explanation.<category>.<risk>" matches the Swift-side
// AtlasFindingExplanations.explanationKey(for:risk:) convention and the
// keys defined in en.lproj/Localizable.strings and zh-Hans.lproj/Localizable.strings.
func explanationKeyFor(category StorageCategory, risk RiskLevel) string {
	return "explanation." + string(category) + "." + string(risk)
}
