# Smart Clean Manual Verification — 2026-03-09

## Goal

Provide a fast, repeatable, machine-local verification flow for the current `Smart Clean` real-execution subset and physical recovery path.

Use this when you want to verify real cleanup behavior on your own Mac without relying on arbitrary personal files.

## Fixture Helper

Use the helper script below to create disposable files only in currently supported Smart Clean execution areas:

- `scripts/atlas/smart-clean-manual-fixtures.sh`

Supported commands:

```bash
./scripts/atlas/smart-clean-manual-fixtures.sh create
./scripts/atlas/smart-clean-manual-fixtures.sh status
./scripts/atlas/smart-clean-manual-fixtures.sh cleanup
```

## What the Helper Creates

The helper creates disposable fixtures under these locations:

- `~/Library/Caches/AtlasExecutionFixturesCache`
- `~/Library/Logs/AtlasExecutionFixturesLogs`
- `~/Library/Developer/Xcode/DerivedData/AtlasExecutionFixturesDerivedData`
- `~/Library/Caches/AtlasExecutionFixturesPycache`
- `~/Library/pnpm/store/v3/files/AtlasExecutionFixturesPnpm`

These locations are chosen because the current Smart Clean implementation can execute and restore them for real.

## Verification Steps

### 1. Prepare fixtures

```bash
./scripts/atlas/smart-clean-manual-fixtures.sh create
```

Expected:
- The script prints the created roots and files.
- `status` shows non-zero size under all five fixture roots.

### 2. Confirm upstream dry-run sees the fixtures

```bash
bash bin/clean.sh --dry-run
```

Expected:
- The dry-run output or `~/.config/mole/clean-list.txt` reflects the fixture size increase under one or more higher-level roots such as:
  - `~/Library/Caches`
  - `~/Library/Logs`
  - `~/Library/Developer/Xcode/DerivedData`
  - `~/Library/pnpm/store`
- The fixture helper `status` output gives you the exact on-disk paths to compare before and after execution.

### 3. Run Smart Clean scan in the app

- Open `Atlas for Mac`
- Go to `Smart Clean`
- Click `Run Scan`
- If needed, use the app search field and search for related visible terms such as `DerivedData`, `cache`, `logs`, or the exact original path shown by the helper script.

Expected:
- A cleanup plan is generated.
- At least one fixture-backed item appears in the plan or filtered findings.
- `Estimated Space` / `预计释放空间` is non-zero.

### 4. Execute the plan

- Review the plan.
- Click `Run Plan` / `执行计划`.

Expected:
- Execution completes successfully for supported fixture items.
- The app creates recovery entries.
- Atlas does not silently claim success for unsupported items.

### 5. Verify physical side effects

```bash
./scripts/atlas/smart-clean-manual-fixtures.sh status
```

Expected:
- Executed fixture files no longer exist at their original paths.
- The corresponding recovery entry exists inside the app.

### 6. Verify scan → execute → rescan

- Run another Smart Clean scan in the app.

Expected:
- The executed fixture-backed items are no longer rediscovered.
- Estimated space drops accordingly.

### 7. Verify physical restore

- Go to `History` / `Recovery`
- Restore the executed fixture-backed item(s)

Then run:

```bash
./scripts/atlas/smart-clean-manual-fixtures.sh status
```

Expected:
- The restored file or directory is back at its original path.
- If the restored item is still reclaimable, a fresh scan can rediscover it.

### 8. Clean up after verification

```bash
./scripts/atlas/smart-clean-manual-fixtures.sh cleanup
```

Expected:
- All disposable fixture roots are removed.

## Failure Interpretation

### Expected failure

If a scanned item is outside the currently supported structured safe subset, Atlas should fail closed instead of pretending to clean it.

### Unexpected failure

Treat these as regressions:

- fixture files remain in place after a reported successful execution
- fixture items reappear immediately on rescan even though the original files are gone
- restore reports success but the original files do not return
- Smart Clean claims success when no executable targets exist

## Recommended Companion Docs

- `Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md`
- `Docs/Execution/Smart-Clean-QA-Checklist-2026-03-09.md`
- `Docs/Execution/Execution-Chain-Audit-2026-03-09.md`
