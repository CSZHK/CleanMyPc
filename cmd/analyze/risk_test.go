package main

import (
	"encoding/json"
	"testing"
)

// ---------------------------------------------------------------------------
// riskLevelForPath – table-driven tests
// ---------------------------------------------------------------------------

func TestRiskLevelForPath(t *testing.T) {
	tests := []struct {
		name string
		path string
		want RiskLevel
	}{
		// -- Edge cases ---------------------------------------------------
		{"empty path returns review", "", RiskReview},
		{"unknown single name returns review", "some_random_dir", RiskReview},
		{"unknown nested path returns review", "/Users/john/Documents/myfile.txt", RiskReview},

		// -- Safe: system caches / temp / trash ---------------------------
		{".cache", "/Users/john/.cache", RiskSafe},
		{"Caches", "/Users/john/Library/Caches/com.apple.Safari", RiskSafe},
		{".tmp", "/tmp/work/.tmp", RiskSafe},
		{".temp", "/tmp/work/.temp", RiskSafe},
		{"tmp", "/tmp/work/tmp", RiskSafe},
		{".Trash", "/Users/john/.Trash", RiskSafe},
		{"__MACOSX", "/Volumes/usb/__MACOSX", RiskSafe},
		{".DS_Store", "/Users/john/.DS_Store", RiskSafe},
		{".Spotlight-V100", "/Volumes/usb/.Spotlight-V100", RiskSafe},
		{".fseventsd", "/Volumes/usb/.fseventsd", RiskSafe},

		// -- Safe: developer build outputs --------------------------------
		{"build", "/Users/john/project/build", RiskSafe},
		{"dist", "/Users/john/project/dist", RiskSafe},
		{".output", "/Users/john/project/.output", RiskSafe},
		{"target", "/Users/john/project/target", RiskSafe},
		{"DerivedData", "/Users/john/Library/Developer/Xcode/DerivedData", RiskSafe},
		{"coverage", "/Users/john/project/coverage", RiskSafe},
		{".nyc_output", "/Users/john/project/.nyc_output", RiskSafe},

		// -- Safe: developer dependency caches ----------------------------
		{"node_modules", "/Users/john/project/node_modules", RiskSafe},
		{"bower_components", "/Users/john/project/bower_components", RiskSafe},
		{".yarn", "/Users/john/project/.yarn", RiskSafe},
		{"vendor", "/Users/john/project/vendor", RiskSafe},
		{".bundle", "/Users/john/project/.bundle", RiskSafe},
		{"Pods", "/Users/john/project/Pods", RiskSafe},
		{"Carthage", "/Users/john/project/Carthage", RiskSafe},

		// -- Safe: developer tool caches ----------------------------------
		{"__pycache__", "/Users/john/project/__pycache__", RiskSafe},
		{".pytest_cache", "/Users/john/project/.pytest_cache", RiskSafe},
		{".mypy_cache", "/Users/john/project/.mypy_cache", RiskSafe},
		{".tox", "/Users/john/project/.tox", RiskSafe},

		// -- Safe: framework caches ---------------------------------------
		{".next", "/Users/john/project/.next", RiskSafe},
		{".nuxt", "/Users/john/project/.nuxt", RiskSafe},
		{".vite", "/Users/john/project/.vite", RiskSafe},
		{".turbo", "/Users/john/project/.turbo", RiskSafe},
		{".parcel-cache", "/Users/john/project/.parcel-cache", RiskSafe},
		{".nx", "/Users/john/project/.nx", RiskSafe},

		// -- Safe: IDE caches ---------------------------------------------
		{".idea", "/Users/john/project/.idea", RiskSafe},
		{".vs", "/Users/john/project/.vs", RiskSafe},

		// -- Safe: other known caches -------------------------------------
		{".Homebrew", "/Users/john/.Homebrew", RiskSafe},
		{".terraform", "/Users/john/project/.terraform", RiskSafe},
		{".dart_tool", "/Users/john/project/.dart_tool", RiskSafe},

		// -- Safe: safe path patterns (substring match) -------------------
		{"Library/Caches pattern", "/Users/john/Library/Caches/com.someapp", RiskSafe},
		{"Library/Logs pattern", "/Users/john/Library/Logs/com.someapp.log", RiskSafe},
		{"Library/DiagnosticReports pattern", "/Users/john/Library/DiagnosticReports/report.diag", RiskSafe},
		{".Trash pattern", "/Users/john/.Trash/oldfile", RiskSafe},
		{"Library/Saved Application State pattern", "/Users/john/Library/Saved Application State/com.someapp.savedState", RiskSafe},

		// -- Safe: projectDependencyDirs ----------------------------------
		{"htmlcov", "/Users/john/project/htmlcov", RiskSafe},
		{".ipynb_checkpoints", "/Users/john/project/.ipynb_checkpoints", RiskSafe},
		{".angular", "/Users/john/project/.angular", RiskSafe},
		{".svelte-kit", "/Users/john/project/.svelte-kit", RiskSafe},
		{".astro", "/Users/john/project/.astro", RiskSafe},
		{".docusaurus", "/Users/john/project/.docusaurus", RiskSafe},
		{".ruff_cache", "/Users/john/project/.ruff_cache", RiskSafe},
		{".eggs", "/Users/john/project/.eggs", RiskSafe},

		// -- Review: developer environments -------------------------------
		// Note: venv, .venv, virtualenv, .gradle, .build are in projectDependencyDirs
		// and thus return RiskSafe. Only truly review-only names are tested here.
		{".pyenv", "/Users/john/.pyenv", RiskReview},
		{".poetry", "/Users/john/.poetry", RiskReview},
		{".pip", "/Users/john/.pip", RiskReview},
		{".pipx", "/Users/john/.pipx", RiskReview},
		{".rbenv", "/Users/john/.rbenv", RiskReview},
		{".nvm", "/Users/john/.nvm", RiskReview},
		{".rustup", "/Users/john/.rustup", RiskReview},
		{".sdkman", "/Users/john/.sdkman", RiskReview},
		{".deno", "/Users/john/.deno", RiskReview},
		{".bun", "/Users/john/.bun", RiskReview},

		// -- Review: developer build caches (expensive to rebuild) --------
		// Note: .gradle, .build are in projectDependencyDirs → RiskSafe.
		{".m2", "/Users/john/.m2", RiskReview},
		{".ivy2", "/Users/john/.ivy2", RiskReview},
		{".cargo", "/Users/john/.cargo", RiskReview},

		// -- Review: package manager caches --------------------------------
		{".npm (review)", "/Users/john/.npm", RiskReview},
		{".composer", "/Users/john/.composer", RiskReview},

		// -- Review: path pattern matches ---------------------------------
		{"Library/Application Support pattern", "/Users/john/Library/Application Support/SomeApp", RiskReview},
		{"Library/Preferences pattern", "/Users/john/Library/Preferences/com.example.app.plist", RiskReview},
		{"Library/Containers pattern", "/Users/john/Library/Containers/com.example.app", RiskReview},
		{"Library/Group Containers pattern", "/Users/john/Library/Group Containers/com.example.app", RiskReview},

		// -- Review: browser data -----------------------------------------
		{"Safari dir", "/Users/john/Library/Safari", RiskReview},
		{"Google dir", "/Users/john/Library/Application Support/Google", RiskReview},
		{"Chrome dir", "/Users/john/Library/Application Support/Google/Chrome", RiskReview},
		{"Firefox dir", "/Users/john/Library/Application Support/Firefox", RiskReview},
		{"BraveSoftware dir", "/Users/john/Library/Application Support/BraveSoftware", RiskReview},

		// -- Advanced: system directories ---------------------------------
		{"System", "/System", RiskAdvanced},
		{"bin", "/usr/bin", RiskAdvanced},
		{"sbin", "/usr/sbin", RiskAdvanced},
		{"etc", "/private/etc", RiskAdvanced},
		{"var", "/private/var", RiskAdvanced},
		{"usr", "/usr", RiskAdvanced},
		{"dev", "/dev", RiskAdvanced},
		{"opt", "/opt", RiskAdvanced},
		{"private", "/private", RiskAdvanced},
		{"cores", "/cores", RiskAdvanced},

		// -- Advanced: virtualization / containers ------------------------
		{".docker", "/Users/john/.docker", RiskAdvanced},
		{".containerd", "/Users/john/.containerd", RiskAdvanced},

		// -- Advanced: databases ------------------------------------------
		{".mysql", "/Users/john/.mysql", RiskAdvanced},
		{".postgres", "/Users/john/.postgres", RiskAdvanced},
		{"mongodb", "/Users/john/mongodb", RiskAdvanced},

		// -- Advanced: iCloud ---------------------------------------------
		{"Mobile Documents", "/Users/john/Library/Mobile Documents", RiskAdvanced},

		// -- Advanced: version control ------------------------------------
		{".git", "/Users/john/project/.git", RiskAdvanced},
		{".svn", "/Users/john/project/.svn", RiskAdvanced},
		{".hg", "/Users/john/project/.hg", RiskAdvanced},

		// -- Advanced: path pattern matches --------------------------------
		{"Library/LaunchAgents pattern", "/Users/john/Library/LaunchAgents/com.example.agent.plist", RiskAdvanced},
		{"Library/LaunchDaemons pattern", "/Library/LaunchDaemons/com.example.daemon.plist", RiskAdvanced},
		{"Library/PrivilegedHelperTools pattern", "/Library/PrivilegedHelperTools/com.example.helper", RiskAdvanced},
		{"Library/SystemExtensions pattern", "/Library/SystemExtensions/com.example.extension", RiskAdvanced},
		{"Library/Extensions pattern", "/Library/Extensions/SomeExtension.kext", RiskAdvanced},

		// -- Advanced takes priority over safe ----------------------------
		{".git (advanced overrides safe foldDirs)", "/Users/john/project/.git", RiskAdvanced},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := riskLevelForPath(tt.path)
			if got != tt.want {
				t.Errorf("riskLevelForPath(%q) = %q, want %q", tt.path, got, tt.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// categoryForPath – table-driven tests
// ---------------------------------------------------------------------------

func TestCategoryForPath(t *testing.T) {
	tests := []struct {
		name string
		path string
		want StorageCategory
	}{
		// -- Edge cases ---------------------------------------------------
		{"empty path returns unknown", "", CategoryUnknown},
		{"unrecognized path returns unknown", "/Users/john/some_random_thing", CategoryUnknown},

		// -- Log files (extension-based) ----------------------------------
		{".log extension", "/Users/john/project/app.log", CategoryLogFile},
		{"log in name", "/Users/john/project/debug.log.1", CategoryLogFile},
		{"Library/Logs path", "/Users/john/Library/Logs/com.apple.install.log", CategoryLogFile},
		{"/var/log path", "/var/log/system.log", CategoryLogFile},

		// -- Browser data -------------------------------------------------
		{"Safari browser path", "/Users/john/Library/Safari/History.db", CategoryBrowserData},
		{"Chrome browser path", "/Users/john/Library/Application Support/Google/Chrome/Default", CategoryBrowserData},
		{"Firefox browser path", "/Users/john/Library/Application Support/Firefox/Profiles", CategoryBrowserData},
		{"Brave browser path", "/Users/john/Library/Application Support/BraveSoftware/Brave-Browser", CategoryBrowserData},
		{"Edge browser path", "/Users/john/Library/Application Support/Microsoft Edge/Default", CategoryBrowserData},
		{"Safari cache", "/Users/john/Library/Caches/com.apple.Safari", CategoryBrowserData},
		{"Chrome cache", "/Users/john/Library/Caches/com.google.Chrome", CategoryBrowserData},
		{"Firefox cache", "/Users/john/Library/Caches/org.mozilla.firefox", CategoryBrowserData},
		{"Safari dir name", "/Users/john/Library/Safari", CategoryBrowserData},
		{"Google dir name", "/Users/john/Library/Application Support/Google", CategoryBrowserData},
		{"Chrome dir name", "/Users/john/Library/Application Support/Google/Chrome", CategoryBrowserData},
		{"Firefox dir name", "/Users/john/Library/Application Support/Firefox", CategoryBrowserData},
		{"BraveSoftware dir name", "/Users/john/Library/Application Support/BraveSoftware", CategoryBrowserData},
		{"Edge dir name", "/Users/john/Library/Application Support/Microsoft Edge", CategoryBrowserData},

		// -- Developer artifacts ------------------------------------------
		{"node_modules", "/Users/john/project/node_modules", CategoryDeveloperArtifact},
		{"build dir", "/Users/john/project/build", CategoryDeveloperArtifact},
		{"dist dir", "/Users/john/project/dist", CategoryDeveloperArtifact},
		{"target dir", "/Users/john/project/target", CategoryDeveloperArtifact},
		{".next", "/Users/john/project/.next", CategoryDeveloperArtifact},
		{".nuxt", "/Users/john/project/.nuxt", CategoryDeveloperArtifact},
		{".vite", "/Users/john/project/.vite", CategoryDeveloperArtifact},
		{".turbo", "/Users/john/project/.turbo", CategoryDeveloperArtifact},
		{".parcel-cache", "/Users/john/project/.parcel-cache", CategoryDeveloperArtifact},
		{".nx", "/Users/john/project/.nx", CategoryDeveloperArtifact},
		{".angular", "/Users/john/project/.angular", CategoryDeveloperArtifact},
		{".svelte-kit", "/Users/john/project/.svelte-kit", CategoryDeveloperArtifact},
		{".astro", "/Users/john/project/.astro", CategoryDeveloperArtifact},
		{".docusaurus", "/Users/john/project/.docusaurus", CategoryDeveloperArtifact},
		{"__pycache__", "/Users/john/project/__pycache__", CategoryDeveloperArtifact},
		{".pytest_cache", "/Users/john/project/.pytest_cache", CategoryDeveloperArtifact},
		{".mypy_cache", "/Users/john/project/.mypy_cache", CategoryDeveloperArtifact},
		{".ruff_cache", "/Users/john/project/.ruff_cache", CategoryDeveloperArtifact},
		{".tox", "/Users/john/project/.tox", CategoryDeveloperArtifact},
		{".eggs", "/Users/john/project/.eggs", CategoryDeveloperArtifact},
		{"htmlcov", "/Users/john/project/htmlcov", CategoryDeveloperArtifact},
		{".ipynb_checkpoints", "/Users/john/project/.ipynb_checkpoints", CategoryDeveloperArtifact},
		{".idea", "/Users/john/project/.idea", CategoryDeveloperArtifact},
		{".vscode", "/Users/john/project/.vscode", CategoryDeveloperArtifact},
		{".vs", "/Users/john/project/.vs", CategoryDeveloperArtifact},
		{"Pods", "/Users/john/project/Pods", CategoryDeveloperArtifact},
		{"Carthage", "/Users/john/project/Carthage", CategoryDeveloperArtifact},
		{".dart_tool", "/Users/john/project/.dart_tool", CategoryDeveloperArtifact},
		{".terraform", "/Users/john/project/.terraform", CategoryDeveloperArtifact},
		{".gradle path", "/Users/john/.gradle/caches", CategoryDeveloperArtifact},
		{".m2 path", "/Users/john/.m2/repository", CategoryDeveloperArtifact},
		{".cargo path", "/Users/john/.cargo/registry", CategoryDeveloperArtifact},
		{".rustup path", "/Users/john/.rustup/toolchains", CategoryDeveloperArtifact},
		{".pyenv path", "/Users/john/.pyenv/versions", CategoryDeveloperArtifact},
		{".nvm path", "/Users/john/.nvm/versions", CategoryDeveloperArtifact},
		{".poetry path", "/Users/john/.poetry/virtualenvs", CategoryDeveloperArtifact},
		{".pip path", "/Users/john/.pip/cache", CategoryDeveloperArtifact},
		{".composer path", "/Users/john/.composer/cache", CategoryDeveloperArtifact},
		{".bundle path", "/Users/john/.bundle/gems", CategoryDeveloperArtifact},
		{"DerivedData", "/Users/john/Library/Developer/Xcode/DerivedData", CategoryDeveloperArtifact},
		{".build", "/Users/john/project/.build", CategoryDeveloperArtifact},
		{"coverage", "/Users/john/project/coverage", CategoryDeveloperArtifact},
		{".coverage", "/Users/john/project/.coverage", CategoryDeveloperArtifact},
		{".nyc_output", "/Users/john/project/.nyc_output", CategoryDeveloperArtifact},
		{".output", "/Users/john/project/.output", CategoryDeveloperArtifact},
		{"out", "/Users/john/project/out", CategoryDeveloperArtifact},
		{"bower_components", "/Users/john/project/bower_components", CategoryDeveloperArtifact},
		{".pnpm-store", "/Users/john/project/.pnpm-store", CategoryDeveloperArtifact},
		{"vendor", "/Users/john/project/vendor", CategoryDeveloperArtifact},
		{".bundle (project)", "/Users/john/project/.bundle", CategoryDeveloperArtifact},
		{"venv", "/Users/john/project/venv", CategoryDeveloperArtifact},
		{".venv", "/Users/john/project/.venv", CategoryDeveloperArtifact},
		{"virtualenv", "/Users/john/project/virtualenv", CategoryDeveloperArtifact},
		{"site-packages", "/Users/john/project/site-packages", CategorySystemCache}, // foldDirs → systemCache
		{".solid", "/Users/john/project/.solid", CategoryDeveloperArtifact},

		// -- Mail attachments ---------------------------------------------
		{"Library/Mail path", "/Users/john/Library/Mail/V10/abc@icloud.com", CategoryMailAttachment},
		{"Library/Containers/com.apple.Mail", "/Users/john/Library/Containers/com.apple.Mail/Data", CategoryMailAttachment},
		{"Group Containers Mail (uppercase)", "/Users/john/Library/Group Containers/group.com.apple.Mail", CategoryMailAttachment},

		// -- Download artifacts -------------------------------------------
		{"Downloads path", "/Users/john/Downloads/installer.dmg", CategoryDownloadArtifact},
		{"Library/Messages path", "/Users/john/Library/Messages/chat.db", CategoryDownloadArtifact},

		// -- Old backups --------------------------------------------------
		{"Backup in path", "/Users/john/Backup/old_backup", CategoryOldBackup},
		{"backup in path", "/Users/john/backup/data", CategoryOldBackup},
		{".backup extension", "/Users/john/project/.backup", CategoryOldBackup},
		{".bak extension", "/Users/john/project/data.bak", CategoryOldBackup},
		{"TimeMachine in path", "/Users/john/TimeMachine/snapshot", CategoryOldBackup},
		{".MobileBackups in path", "/Users/john/.MobileBackups/snapshot", CategoryOldBackup},

		// -- System cache -------------------------------------------------
		{"Library/Caches path", "/Users/john/Library/Caches/com.someapp.cache", CategorySystemCache},
		{"Library/Saved Application State path", "/Users/john/Library/Saved Application State/com.someapp.savedState", CategorySystemCache},
		{"Library/DiagnosticReports path", "/Users/john/Library/DiagnosticReports/some_report.diag", CategorySystemCache},
		{".Trash path", "/Users/john/.Trash/deleted_file.txt", CategorySystemCache},
		{".cache path", "/Users/john/.cache/some_cache", CategorySystemCache},
		{"/Caches/ path", "/Users/john/Library/Caches/someapp", CategorySystemCache},

		// -- App cache ----------------------------------------------------
		{"Library/Application Support path", "/Users/john/Library/Application Support/SomeApp/data", CategoryAppCache},
		{"Library/Containers path", "/Users/john/Library/Containers/com.someapp/Data", CategoryAppCache},
		{"Library/Preferences path", "/Users/john/Library/Preferences/com.someapp.plist", CategoryAppCache},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := categoryForPath(tt.path)
			if got != tt.want {
				t.Errorf("categoryForPath(%q) = %q, want %q", tt.path, got, tt.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// explanationKeyFor – every category+risk combination
// ---------------------------------------------------------------------------

func TestExplanationKeyFor(t *testing.T) {
	tests := []struct {
		name     string
		category StorageCategory
		risk     RiskLevel
		want     string
	}{
		// System cache at each risk level.
		{"systemCache.safe", CategorySystemCache, RiskSafe, "smartclean.explanation.systemCache.safe"},
		{"systemCache.review", CategorySystemCache, RiskReview, "smartclean.explanation.systemCache.review"},
		{"systemCache.advanced", CategorySystemCache, RiskAdvanced, "smartclean.explanation.systemCache.advanced"},

		// App cache.
		{"appCache.safe", CategoryAppCache, RiskSafe, "smartclean.explanation.appCache.safe"},
		{"appCache.review", CategoryAppCache, RiskReview, "smartclean.explanation.appCache.review"},
		{"appCache.advanced", CategoryAppCache, RiskAdvanced, "smartclean.explanation.appCache.advanced"},

		// Developer artifacts.
		{"developerArtifact.safe", CategoryDeveloperArtifact, RiskSafe, "smartclean.explanation.developerArtifact.safe"},
		{"developerArtifact.review", CategoryDeveloperArtifact, RiskReview, "smartclean.explanation.developerArtifact.review"},
		{"developerArtifact.advanced", CategoryDeveloperArtifact, RiskAdvanced, "smartclean.explanation.developerArtifact.advanced"},

		// Browser data.
		{"browserData.safe", CategoryBrowserData, RiskSafe, "smartclean.explanation.browserData.safe"},
		{"browserData.review", CategoryBrowserData, RiskReview, "smartclean.explanation.browserData.review"},
		{"browserData.advanced", CategoryBrowserData, RiskAdvanced, "smartclean.explanation.browserData.advanced"},

		// Log files.
		{"logFile.safe", CategoryLogFile, RiskSafe, "smartclean.explanation.logFile.safe"},
		{"logFile.review", CategoryLogFile, RiskReview, "smartclean.explanation.logFile.review"},
		{"logFile.advanced", CategoryLogFile, RiskAdvanced, "smartclean.explanation.logFile.advanced"},

		// Download artifacts.
		{"downloadArtifact.safe", CategoryDownloadArtifact, RiskSafe, "smartclean.explanation.downloadArtifact.safe"},
		{"downloadArtifact.review", CategoryDownloadArtifact, RiskReview, "smartclean.explanation.downloadArtifact.review"},
		{"downloadArtifact.advanced", CategoryDownloadArtifact, RiskAdvanced, "smartclean.explanation.downloadArtifact.advanced"},

		// Mail attachments.
		{"mailAttachment.safe", CategoryMailAttachment, RiskSafe, "smartclean.explanation.mailAttachment.safe"},
		{"mailAttachment.review", CategoryMailAttachment, RiskReview, "smartclean.explanation.mailAttachment.review"},
		{"mailAttachment.advanced", CategoryMailAttachment, RiskAdvanced, "smartclean.explanation.mailAttachment.advanced"},

		// Old backups.
		{"oldBackup.safe", CategoryOldBackup, RiskSafe, "smartclean.explanation.oldBackup.safe"},
		{"oldBackup.review", CategoryOldBackup, RiskReview, "smartclean.explanation.oldBackup.review"},
		{"oldBackup.advanced", CategoryOldBackup, RiskAdvanced, "smartclean.explanation.oldBackup.advanced"},

		// Unknown category.
		{"unknown.safe", CategoryUnknown, RiskSafe, "smartclean.explanation.unknown.safe"},
		{"unknown.review", CategoryUnknown, RiskReview, "smartclean.explanation.unknown.review"},
		{"unknown.advanced", CategoryUnknown, RiskAdvanced, "smartclean.explanation.unknown.advanced"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := explanationKeyFor(tt.category, tt.risk)
			if got != tt.want {
				t.Errorf("explanationKeyFor(%q, %q) = %q, want %q", tt.category, tt.risk, got, tt.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// JSON entry serialization – new fields and backward compatibility
// ---------------------------------------------------------------------------

func TestJSONEntryHasNewFields(t *testing.T) {
	entry := jsonEntry{
		Name:            "node_modules",
		Path:            "/Users/john/project/node_modules",
		Size:            1024,
		IsDir:           true,
		RiskLevel:       "safe",
		StorageCategory: "developerArtifact",
		LastAccessed:    "2025-01-01T00:00:00Z",
		CreatedDate:     "2024-06-15T12:00:00Z",
		ExplanationKey:  "smartclean.explanation.developerArtifact.safe",
	}

	data, err := json.Marshal(entry)
	if err != nil {
		t.Fatalf("json.Marshal entry: %v", err)
	}

	// Verify all new fields are present in the JSON output.
	fields := map[string]string{
		`"risk_level"`:            "safe",
		`"storage_category"`:      "developerArtifact",
		`"last_accessed"`:         "2025-01-01T00:00:00Z",
		`"created_date"`:          "2024-06-15T12:00:00Z",
		`"explanation_key"`:       "smartclean.explanation.developerArtifact.safe",
	}
	for field, val := range fields {
		if !containsSubstring(string(data), field) {
			t.Errorf("JSON output missing field %s: %s", field, string(data))
		}
		if !containsSubstring(string(data), val) {
			t.Errorf("JSON output missing value %s for field: %s", val, string(data))
		}
	}
}

func TestJSONEntryBackwardCompatibility(t *testing.T) {
	entry := jsonEntry{
		Name:  "build",
		Path:  "/Users/john/project/build",
		Size:  2048,
		IsDir: true,
	}

	data, err := json.Marshal(entry)
	if err != nil {
		t.Fatalf("json.Marshal entry: %v", err)
	}

	// Existing fields must still be present.
	requiredFields := []string{`"name"`, `"path"`, `"size"`, `"is_dir"`}
	for _, field := range requiredFields {
		if !containsSubstring(string(data), field) {
			t.Errorf("backward compat: JSON missing required field %s: %s", field, string(data))
		}
	}

	// Omitted fields should not appear (omitempty).
	omittedFields := []string{`"risk_level"`, `"storage_category"`, `"last_accessed"`, `"created_date"`, `"explanation_key"`}
	for _, field := range omittedFields {
		if containsSubstring(string(data), field) {
			t.Errorf("backward compat: omitted field %s should not appear: %s", field, string(data))
		}
	}
}

func TestJSONOutputStructure(t *testing.T) {
	output := jsonOutput{
		Path:       "/Users/john",
		TotalSize:  5000,
		TotalFiles: 10,
		Entries: []jsonEntry{
			{
				Name:            ".cache",
				Path:            "/Users/john/.cache",
				Size:            1000,
				IsDir:           true,
				RiskLevel:       "safe",
				StorageCategory: "systemCache",
				ExplanationKey:  "smartclean.explanation.systemCache.safe",
			},
			{
				Name:            "Documents",
				Path:            "/Users/john/Documents",
				Size:            4000,
				IsDir:           true,
				RiskLevel:       "review",
				StorageCategory: "unknown",
				ExplanationKey:  "smartclean.explanation.unknown.review",
			},
		},
	}

	data, err := json.Marshal(output)
	if err != nil {
		t.Fatalf("json.Marshal output: %v", err)
	}

	// Top-level fields must exist.
	topFields := []string{`"path"`, `"entries"`, `"total_size"`, `"total_files"`}
	for _, field := range topFields {
		if !containsSubstring(string(data), field) {
			t.Errorf("JSON output missing top-level field %s: %s", field, string(data))
		}
	}
}

// ---------------------------------------------------------------------------
// isDeveloperArtifactName – spot checks
// ---------------------------------------------------------------------------

func TestIsDeveloperArtifactName(t *testing.T) {
	tests := []struct {
		name string
		input string
		want  bool
	}{
		{"__pycache__", "__pycache__", true},
		{".pytest_cache", ".pytest_cache", true},
		{".next", ".next", true},
		{"build", "build", true},
		{"dist", "dist", true},
		{".idea", ".idea", true},
		{".vs", ".vs", true},
		{"Pods", "Pods", true},
		{".terraform", ".terraform", true},
		{"random_dir", "random_dir", false},
		{"Documents", "Documents", false},
		{"Downloads", "Downloads", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := isDeveloperArtifactName(tt.input)
			if got != tt.want {
				t.Errorf("isDeveloperArtifactName(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

// helper: string contains check.
func containsSubstring(s, sub string) bool {
	return len(s) >= len(sub) && searchString(s, sub)
}

func searchString(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
