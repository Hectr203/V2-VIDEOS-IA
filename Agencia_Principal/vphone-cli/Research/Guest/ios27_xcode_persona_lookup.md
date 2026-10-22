# Xcode installation and UserManager on the iOS 27 hybrid guest

Environment: pcc-research-01; iOS 27.0.1 (24A446), cloudOS 26.4 (23E5207q);
Xcode 27.0 (27A266a). Investigated 2026-10-07.

## Evidence

Xcode Run failed with CoreDevice 3002, MIInstallerErrorDomain 4 (empty persona
list) and NSCocoaErrorDomain 4099. The corresponding guest log was:

```
Protobox: installcoordination_proxy(404) deny(1) mach-lookup com.apple.mobile.usermanagerd.xpc
```

UserManager was running; the proxy already carried
`com.apple.usermanagerd.persona.fetch`. The same EasyTier.app installed through
ideviceinstaller and launched successfully. That legacy entry point uses
mobile_installation_proxy/installd and does not test CoreDevice's preceding
installation-coordination persona lookup. The failure was not evidence of a
missing persona database, app provisioning failure or UserManager crash.

An initial experiment appended the one UserManager mach-lookup exception to
the proxy's entitlements and deployed it. Reading the live binary confirmed
the entitlement was present, but Xcode still generated the identical Protobox
denial. It is therefore insufficient for this platform profile, consistent
with the independently investigated Control Center volume service failure in
[ios27_cc_volume_sandbox.md](ios27_cc_volume_sandbox.md).

## IDA analysis

Analyzed the guest's actual `/sbin/launchd` with IDA MCP. Its
`_sandbox_check_by_audit_token` import stub is at `0x10005e404`.
`sub_100037028` at `0x100037028` calls it with `mach-lookup` and the service
name; the code selects name filter 3, 2 or 12 according to the bootstrap
domain. The 32-byte audit-token struct follows the arm64 by-value ABI (copied
to memory), and the service name occupies the first variadic argument.
These addresses identify this binary, not an address-based patch.

## Scoped compatibility

The existing launchdhook interposes this function. The new case requires:

- The exact `mach-lookup` operation and name filter 2, 3 or 12.
- Exact service `com.apple.mobile.usermanagerd.xpc`.
- A regular, root-owned enable marker with no group/other write bits.
- `proc_pidpath` matching the system InstallCoordination support executable.
- `csops_audittoken(CS_OPS_IDENTITY)` succeeding for the incoming audit token
  and returning `com.apple.installcoordination_proxy`.

The kernel checks both PID and PID version for csops_audittoken, avoiding a
PID-only identity decision. The identity result has an eight-byte blob header
followed by the NUL-terminated identifier. Sources:
[Apple codesign.h](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/codesign.h)
and [kern_proc.c](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_proc.c).
The service's own persona authorization is unchanged. There is no generic
UserManager allowlist, sandbox disable, or host security-setting change.

Patch `system-installcoordination_proxy-cfw-persona_lookup` installs/removes
`/usr/lib/vphone-installcoordination-persona-lookup` and records the result.
The installer restores the failed experimental proxy modification from its
backup when migrating an already patched machine. The original VM disk and
patch receipts were cloned to `/tmp/vphone-pre-persona-fix` before deployment.

## Validation

The host C harness passes the permitted filters and rejects other operations,
services, executable paths, signing identifiers, stale audit tokens, missing
markers, symlinks, non-root owners and writable markers. Deployment through Launchpad completed; after reboot, Xcode Run installed
EasyTier and displayed `Running EasyTier on iPhone`. Guest `apps.foreground`
confirmed `cn.easytier`, PID 441, `verified: true`. The hook log recorded two
`allow mach-lookup com.apple.mobile.usermanagerd.xpc` entries.

The live installation proxy was pulled back and compared with the pre-change
binary: both SHA-256 hashes were
`acc3676f9b1d56eec0278a64cbd53fc0b1c54d1c2b8f56d91b7570f049d5b87c`.
Thus the successful Xcode install did not depend on the failed entitlement
experiment. The bundle build and its validation passed, as did all 50 tests
in the six required patch model/catalogue suites.

LLDB warned that the host lacked the device's on-disk shared cache and was
reading symbols from process memory; Xcode subsequently asked to continue
waiting. This is separate from installation and can delay initial debugger
startup. Continue was selected; no claim of breakpoint/step validation yet.
