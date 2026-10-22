# Settings row patch research tools

These standalone Swift research tools reproduce the tested 24A435 Preferences edits. The combined library is now wired into the installer and patch catalogue; these standalone research scripts are not shipping commands. Indexing is excluded. No tool writes to a guest or signs a file.

Both compile against the repository's built VPhonePatchKit.framework. ReviewedProviderPatch takes an original Mach-O path, explicit `--providers` (comma separated), and a new `--output` path. It accepts only the reviewed Preferences/GeneralSettingsUI hashes, checks the hash before parsing, resolves Swift resilient witnesses and instruction structure, and refuses missing/ambiguous providers or existing output. GameCenterStandalonePatch takes original Preferences and a new output path; it resolves MCFeatureGameCenterAllowed from native symbol/indirect-pointer tables rather than an external disassembler export.

Use the original image for each tool. Game Center and the three provider edits must be combined as non-overlapping diffs against that same original before signing. The deployed combined candidate has been verified independently; these tools do not yet provide a combined installer command. The GeneralSettingsUI output is an extracted analysis image and must never be installed as a dyld cache file.

Validation on 2026-10-07:
- Native-symbol Game Center output matches the previously deployed rule-edit candidate byte for byte.
- ReviewedProviderPatch output for Apple Account, iCloud and Wallet matches Preferences.review-v3 byte for byte.
- Missing arguments, truncated/unreviewed input, excluded Indexing provider, provider absent from the input, and output overwrite are refused.
- Live four-row deployment, rollback, and full reboot evidence is recorded in ../settings_app_row_hiding.md.

Five-row live deployment, rollback and reboot validation are complete. Software Update is now integrated as `dyld-exp-settings_software_update_row` using native cache discovery and the standard undo log. No new Bundle release was requested or published.

## Combined library implementation

`FirmwarePatcher/CustomFirmware/ExecutablePatches/SettingsRows/CustomFirmwareSettingsRows.swift` now exposes `patchPreferences(_:)`. It performs all four root-row transformations in memory and returns five instruction records with their original and replacement bytes. Discovery and overlap checks finish before output is returned. It accepts only the reviewed original Preferences image, so callers must use their pristine backup rather than a previously signed or patched image.

The combined result was compiled in Swift 6 mode with warnings as errors, matched the tested unsigned combined candidate byte for byte, rejected empty/truncated/already-patched input, and restored the original byte for byte using its edit records. The library is called by `cfw patch-settings-root-rows` through the common Mach-O installer and declared as `system-preferences-exp-root_rows`; standard blocks it. Full source build and command dry-run/real-output equality pass. Xcode catalogue and regression tests are being verified separately.

Final validation: 52 Xcode tests passed; complete Release CLI build passed. Software Update command dry-run, apply, repeat and standard revert reproduce the field-tested bytes. See ../2026-10-07_reverse-settings-rows-report.md.
