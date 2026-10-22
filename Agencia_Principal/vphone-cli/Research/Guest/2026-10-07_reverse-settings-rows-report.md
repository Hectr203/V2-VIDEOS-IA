# Settings row hiding: deployment and rollback verification

## Outcome and scope

On 2026-10-07, panetest-iphone (iOS 27.0, build 24A435) hid Apple Account, Game Center, iCloud, Wallet & Apple Pay, and Software Update. The four root rows and the General > Software Update row passed restoration, reappearance, reapplication, and full-reboot checks. Indexing/Search & Siri was explicitly excluded and its provider was unchanged. The guest retained its original admitted Core Bundle, 2.6.0-local.92448989. Unrelated kernel and SEP experiments were not deployed by this work.

The user authorized implementation, deployment and verification, including a temporary writable mount after the approval review requested explicit authorization. Each temporary mount job was unloaded and removed. Final checks found the root filesystem read-only and no residual mount job, plist or log.

Both patch implementations are integrated into the source installer. The final CLI produces exactly the bytes tested in the guest. The live deployment used recoverable file replacements under the original Bundle; a newly packaged Bundle has not been deployed. This distinction, narrow firmware coverage, and remaining installer-level validation make this a WIP PR rather than a release claim.

## Evidence, findings and reproduction paths

| Evidence | Finding | Verification path |
|---|---|---|
| `SettingsRows/Evidence-20261007/rollback-root-top.json`, `rollback-root-bottom.json` | Restoring original Preferences restores all four root rows | Original executable → candidate → original → candidate, relaunching Settings each time |
| `SettingsRows/Evidence-20261007/software-update-rollback-ui.json` | Restoring the original cache restores Software Update | Restore the cache chunk and fully reboot |
| `SettingsRows/Evidence-20261007/final-root-top-ui.json`, `final-root-lower-ui.json`, `final-general-ui.json` | All five targets are absent and neighboring rows remain | Assert each relevant UI region after the final full reboot |
| Local `final-environment.json`, `final-services.json`, `final-root-files.json` | Root is read-only; the temporary mount service and files are absent | Read back environment.status, services.list and files.list |
| Local `five-row-integration-tests.log`, `patch-model-tests.log` | 52 tests passed, including real executable and cache fixtures | Isolated Xcode build and test runs |

Local artifacts in this report are under `/private/tmp/prefs-audit` on the research host and are not portable fixtures. The UI evidence listed with repository-relative paths is included with the research notes. Apple binaries and cache chunks are not included.

The final verified boot session was `0980B399-163F-4EBA-B8D0-51A115AD4D80`. Settings launched with PID 377 and `frontmost_verified=true`. The first Software Update deployment used boot session `2BB7E8F3-F3BF-453B-9DEE-13E3B7B0731B`.

## Implementation and integrity

For three Preferences rows, resilient Swift witness metadata locates each provider's Optional branch. The replacement takes its existing cleanup path and returns an empty value. For Game Center, native Mach-O indirect-symbol lookup locates the construction block associated with `MCFeatureGameCenterAllowed`; only its sharedPad rule is replaced with boolean(false,false). The five instructions are discovered structurally. A hash gate restricts Preferences to the reviewed pristine input. Signing preserved all 767 original entitlement keys and values.

The actual Software Update row identifier is `com.apple.settings.general.softwareUpdate` in GeneralSettingsUI. In this fixture, the discovered instruction maps to cache chunk `.36`, file offset 23494832. This offset is evidence for this sample, not a cross-version discovery rule. `DyldSharedCacheChunkSet` captures original bytes, and re-attestation updates page 1434's signature slot at file offset 131347490. Only the instruction and one page hash differ, totaling 35 changed bytes. Upload/download comparison matched, and undo plus re-attestation restored the entire original chunk.

| Artifact | SHA-256 |
|---|---|
| Original Preferences | `e59851f14f29409590a6de76ca2fe9b9912341aee526a278692ef0d7a86ee2f3` |
| Deployed signed Preferences | `dc92f2f36d1f5fbb3e8f84f52487e000fe353accf99181561b4df590031a75b5` |
| Original cache chunk | `62a41422d07cf098ee848f20a793747196c0ba59b05b42348620fe6c672419bb` |
| Deployed cache chunk | `dd79a85eb90dbe9dab116220ad2a5cde32109054e6f8bef5bee9e131690240c4` |

## Recovery and installer integration

Guest executable backups are `/Applications/Preferences.app/Preferences.rows-original-20261007` and `Preferences.rows-previous-20261007`. The original cache is saved as `/System/Cryptexes/OS/System/Library/Caches/com.apple.dyld/.settings-rows-cache36-original-20261007`; additional copies exist in guest staging and host research storage. Cache restoration requires a writable mount, file replacement and a full reboot. An extracted dylib must never be installed as a cache chunk.

`cfw patch-settings-root-rows` implements `system-preferences-exp-root_rows`. It accepts a pristine Preferences copy; its caller signs the result. The installer uses its existing `.bak`, entitlement-preservation, signing and restoration paths.

`DyldSharedCacheSettingsRowsPatcher`, exposed by `cfw patch-settings-software-update`, implements `dyld-exp-settings_software_update_row`. The installer supplies `--undo-log` and `--undo-id`; deselection uses `patch-dsc-revert` to restore bytes and re-attest the page. Both declarations are blocked by the standard preset and remain off for legacy machines without a patch plan. Cache discovery reads the reviewed image UUID, provider type name, resilient witnesses and LC_FUNCTION_STARTS; it needs no extraction tool, fixed instruction address or external symbol listing. Older standalone scripts remain research artifacts only.

## Validation and WIP boundaries

The complete Release VPhoneCommand build passed. Three fixture/catalogue suites passed 20 tests, including the real Preferences and full-cache fixtures. Five patch-model suites passed another 32 tests. Cache coverage includes dry-run, equality with deployed bytes, idempotent repetition with no new undo record, and exact restoration. The same sequence was exercised through the new CLI and the standard revert command. `git diff --check` passed.

These results were obtained in the original mixed research checkout. The isolated PR branch is validated separately in the PR description. Support is intentionally restricted to the reviewed 24A435 input/UUID. Live tests prove the candidate bytes, not a newly packaged Bundle's end-to-end installation. Broader fixture coverage, a packaged installer run, and adoption of the manually deployed guest into managed patch receipts remain follow-up work.

Related app-entry removal and OTA-blocking experiments are documented in `post_setup_signin_and_appstore.md` and `ota_software_update_block.md`. They are manual research procedures, not additional automatic behavior of these two Settings patches.

### Isolated WIP branch verification

The PR branch was rebuilt independently from upstream main at `2d21d21f`, without the parallel kernel/SEP, IOMFB or libprefsfix changes. All 54 tests in 9 selected suites passed, including both real fixtures and the standalone store-encoding tests. The complete Release VPhoneCommand CLI build also passed. This verifies the scoped source branch; the packaged Bundle deployment boundary above still applies.
