# iOS 27 Control Center volume slider: a sandbox-profile mismatch

On an iOS 27.0 guest (iOS 27 userland over the cloudOS 26.4 kernel), Control
Center's volume slider is stuck full and will not move. The hardware volume keys
work. `Research/Guest/virtio_sound.md` §8 recorded the symptom; this note traces
it, records that the first fix attempt (a mach-lookup exception entitlement on
SpringBoard) was **deployed and did not work**, explains why, and lays out the
remaining options with their blast radius.

**Fixed (2026-10-04).** Option 1 — a launchd interpose of
`sandbox_check_by_audit_token` that allows SpringBoard's one lookup of the
volume service — is implemented and boot-tested on `mictest-iphone`: the guest
boots (launchd survives the pid-1 interpose), the interpose logs the allow, and
the Control Center slider tracks a drag (volume 0.59 → 0 → 0.62, where before it
was stuck at 0.44 and inert). See "The fix" below.

## Symptom (verified)

Opening Control Center, slider confirmed full and inert by screenshot:

```
kernel: Protobox: SpringBoard(36) deny(1) mach-lookup com.apple.mediaexperience.avvolumeclient.xpc
SpringBoard: -AVVolumeClient- -[AVVolumeClient initInternalWithType:]: Failed to create FigVolumeController for type 1: -16155
SpringBoard: [MRAVVolumeClientEndpoint] VolumeController unavailable; will retry on next activation
```

Dragging the slider leaves `audio.state` `active_volume` at 0.4375 (unchanged).
The kernel line is rate-limited after the first hit.

## What "Protobox" is, and how a mach-lookup is enforced (verified + inferred)

"Protobox" is the compiled-profile evaluation engine in the Sandbox kext on the
iOS 17+/26 generation; its deny log prefix is `Protobox:` where older kernels
logged `Sandbox:`. A `mach-lookup` is the XPC/bootstrap service look-up gate:
when a client connects to a Mach service, launchd (via libxpc, in the shared
cache) asks the Sandbox kext whether the **client** may look up that global
name — `sandbox_check_by_audit_token(client_token, "mach-lookup",
SANDBOX_FILTER_GLOBAL_NAME, name)`. The kernel's Protobox evaluates the client's
compiled profile and returns allow/deny, logging the deny with the client's
name/pid (hence `SpringBoard(36)`, not launchd). **It is not a `mac_policy_ops`
MACF hook**, so the project's `kernel-boot-sandbox_ext` ops-table retarget cannot
reach it. (Verified: the call site being in launchd/libxpc is standard iOS
internals; the in-kernel Protobox eval + its log is confirmed by the kernel-side
log line. The exact userspace symbol was not disassembled here.)

## Where SpringBoard's profile comes from (verified)

The booting kernel is the cloudOS 26.4 research kernelcache
(`…/FirmwareOriginals/…/kernelcache.research.vphone600`,
`Darwin Kernel Version 25.4.0 … xnu-12377.100.591.502.1~2/RELEASE_ARM64_VRESEARCH1`),
and it contains the Sandbox kext (`com.apple.security.sandbox`).

iOS 27 ships **no** userland platform sandbox-profile collection:
`/System/Library/Sandbox/Profiles` on the guest holds only
`com.apple.doorsd.sb`. The platform profiles for system processes — SpringBoard
among them (`com.apple.springboard` and the `SpringBoard.app/SpringBoard` path
are strings in the kernel's collection) — are baked into the Sandbox kext's
builtin collection in the **cloudOS 26.4** kernelcache. That is the profile the
Protobox evaluator applies to SpringBoard.

## Why the lookup is denied (verified)

The server side is fine: `/System/Library/LaunchDaemons/com.apple.audiomxd.plist`
(iOS 27) lists `com.apple.mediaexperience.avvolumeclient.xpc` in MachServices.

The 26.4 profile predates the service. `strings` on the decompressed
kernelcache:

| service / entitlement | in 26.4 kernel collection? |
| --- | :-: |
| `com.apple.coremedia.volumecontroller.xpc` (old volume service) | yes |
| `com.apple.mediaexperience.carplaymodecontroller.xpc` | yes |
| `com.apple.mediaexperience.systemmediacastingcontroller.xpc` | yes |
| `com.apple.mediaexperience.endpoint.xpc` | yes |
| **`com.apple.mediaexperience.avvolumeclient.xpc`** | **no** |
| entitlement `com.apple.private.mediaexperience.controlcentervolumeclient.allow` | **no** |

So no profile in the 26.4 collection names the service, and no rule is gated on
the `controlcentervolumeclient.allow` entitlement SpringBoard holds.

## The exception-entitlement fix was deployed and FAILED (verified)

The first attempt (commit f0d2a04, reverted on this branch) merged
`com.apple.mediaexperience.avvolumeclient.xpc` into SpringBoard's own
`com.apple.security.exception.mach-lookup.global-name` entitlement array and
re-signed — the mechanism Apple provides and the project uses for Campo (row
14). The coordinator deployed it on `mictest-iphone` (bundle 2.4.0-local.e0d48739,
via `--update-environment`). Result, verified by pulling the live binaries:

- **The entitlement is present, in the authoritative form.** The re-signed
  SpringBoard (121904 B, CDHash `aaa80bc3…`, ad-hoc) has a well-formed DER
  entitlements blob whose `com.apple.security.exception.mach-lookup.global-name`
  array is `[com.apple.mobileasset.autoasset,
  com.apple.usernotifications.subscriber-service.launching,
  com.apple.usernotifications.subscriber-service.non-launching,
  com.apple.mediaexperience.avvolumeclient.xpc]` — our name is there (DER:
  `…global-name0\x82\x0b5\x0c\x1f…avvolumeclient.xpc`).
- **The denial is unchanged** in that same boot, slider still dead.

So the premise "SpringBoard already carries the exception array, so its profile
honours it" is false **for SpringBoard's profile**.

### It is the profile, not the signature (verified)

Two hypotheses for the failure; the second is ruled out:

- **DER vs XML (ruled out).** `VPhoneSigner` emits both forms
  (`signature.entitlements = (combined.xml(), combined.der)`), but `codesign -d
  --entitlements :-` prints nothing and warns *"binary contains an invalid
  entitlements blob. The OS will ignore these entitlements"* — the **XML** blob
  it writes is malformed. The **DER** blob is valid and carries the name. This
  is not the cause, because **Campo is re-signed by the identical path and shows
  the identical signature shape** (invalid XML blob, valid DER) yet its
  mach-lookup exception entitlements are honoured — Campo (the wallpaper
  renderer) renders, which it cannot do if its backboard/frontboard exception
  lookups were denied (row 14). Modern AMFI/sandbox read DER; the malformed XML
  blob is harmless here. *(It is still a latent `VPhoneSigner` bug — see below.)*
- **Profile (the cause).** Campo runs under the `temporary-sandbox` profile (its
  declared `com.apple.private.sandbox.profile:embedded`), which honours the
  mach-lookup exception entitlement. SpringBoard runs under its **platform
  profile**, which does not apply exception-derived mach-lookup rules (platform
  profiles bake their allows in; exception entitlements are a third-party-app
  escape hatch). The Campo precedent is therefore a **different process with a
  different profile**, and does not transfer to SpringBoard.

  Supporting detail: of SpringBoard's three Apple-provided exception names,
  `com.apple.mobileasset.autoasset` **is** in the kernel collection (allowable
  by literal name), while `com.apple.usernotifications.subscriber-service.launching`
  is **absent** from it — i.e. Apple listed names in the array that the base
  profile does not allow, expecting the exception to cover them on a matching
  kernel. On this 26.4 kernel that coverage is what is missing for SpringBoard.

  **Inferred, not bytecode-proven:** the exact rule (or its absence) inside
  SpringBoard's compiled profile was not read out — the kernelcache has no
  symbols and no profile decompiler was available for the Protobox format. The
  behavioural evidence (identical signing, opposite result, known
  platform-vs-temporary-sandbox distinction) is strong and consistent.

**Conclusion: the exception-entitlement route is dead for SpringBoard. The patch
was removed from this branch.**

## Separate bug found: VPhoneSigner writes an invalid XML entitlements blob

Every binary re-signed by `VPhoneSigner` (SpringBoard and Campo both observed)
has a malformed legacy XML entitlements slot — `codesign` reports it invalid and
says the OS ignores it. Harmless for AMFI and the sandbox (DER is authoritative),
but any consumer that still reads the XML/CFDictionary entitlements
(`CSSLOT_ENTITLEMENTS`) gets nothing. Worth fixing in `VPhoneSign` independently
of this issue. Not addressed here.

## Fix options (ranked), with blast radius

The profile is fixed in the kernelcache and cannot be recompiled; the exception
entitlement does not help. Every remaining route touches a boot-critical surface
and needs live validation on a VM the owner controls.

1. **launchd-side sandbox-check short-circuit (recommended, narrowest).**
   The gate is a userspace call in launchd/libxpc
   (`sandbox_check_by_audit_token`, operation `"mach-lookup"`). The project
   already injects `launchdhook-vphone.dylib` into launchd (pid 1) and interposes
   `posix_spawn`/`memorystatus_control` there via `__DATA,__interpose`; dyld
   interposition reaches the shared cache's own callers (the MISFix row documents
   exactly this). Add an interpose of `sandbox_check_by_audit_token` that returns
   0 (allow) **only** when `operation == "mach-lookup"` and the global-name
   argument `== "com.apple.mediaexperience.avvolumeclient.xpc"`, and otherwise
   forwards unchanged.
   - **Opens:** any client (not just SpringBoard) may look up that one volume
     service. Low impact — it is a volume controller.
   - **Who it affects:** only callers that look up that exact name (SpringBoard's
     Control Center volume client; possibly mediaremoted / other volume UI).
   - **Risk / why not shipped blind:** it is a pid-1 interpose of a **variadic**
     function. Matching the real ABI (the `audit_token_t` by-value struct, the
     filter-type width, the single string variadic) and forwarding non-target
     calls correctly must be confirmed against the live signature; a mistake
     crash-loops launchd → unbootable guest. Needs the private `sandbox.h`
     signature and a boot test. This is why it is handed over rather than
     committed.

2. **Kernel patch: allow the `mach-lookup` operation in Protobox (broad
   fallback).** A semantic kernel patch making the Protobox mach-lookup
   evaluation always allow.
   - **Opens:** **every** sandboxed guest process may look up **every**
     registered Mach service — it removes the mach-lookup sandbox boundary for
     the whole guest.
   - **Who it affects:** all processes (apps included). Consistent with this
     guest's already-dismantled sandbox posture (30+ hooks neutered by
     `kernel-boot-sandbox_ext`, container upcall bypassed, AMFI off), but it is
     the broad "disable the sandbox" change and must be stated as such.
   - **Risk:** needs the Protobox decision anchor located in a sym+ decompiler-
     free kext, and a boot test; broad.

3. **Service rename to an allowed name (rejected).** Make audiomxd advertise the
   avvolumeclient endpoint under a name SpringBoard's profile already allows and
   interpose SpringBoard's lookup string. Rejected: needs an allowed-but-unused
   name for SpringBoard (unknown without the profile), is two-sided (audiomxd's
   plist + its dispatch + SpringBoard's lookup), and the obvious candidate
   `com.apple.coremedia.volumecontroller.xpc` is already in use and speaks a
   different protocol.

4. **Compiled-profile binary edit in the kernelcache (rejected).** Insert an
   allow rule for the name into SpringBoard's compiled profile. Rejected:
   editing Protobox bytecode (string table + filter graph + offsets) with no
   (de)serializer is extremely fragile and not a semantic anchor; a rejected
   profile breaks boot or the whole guest sandbox.

## The `sandbox_check_by_audit_token` ABI, confirmed (2026-10-04)

Option 1 needs the live signature before any pid-1 interpose can be written.
Read from `libsystem_sandbox.dylib`, extracted from the guest's shared cache
(26.6; this is a stable libsystem API and does not change into 27). The
exported `_sandbox_check_by_audit_token` (at `0x2a4153c50`) disassembles to:

```
mov  x19, x2            ; filter type kept
mov  x20, x0            ; x0 is a POINTER to the token
stp  xzr, x1, [x29,-0x20]
sub  x0, x29, #0x18
bl   _sandbox_operation_fixup   ; operates on the x1 operation string
...
ldr  w8, [x20, #0x14]   ; reads token fields through x20 (= x0)
ldr  w9, [x20, #0x1c]
...
add  x2, x29, #0x10     ; x2 = incoming sp = va_list of the stack args
bl   _sandbox_check_common
retab
```

So the ABI is:

- **x0** — pointer to the `audit_token_t` (the source signature passes it by
  value; a 32-byte composite is >16 bytes, so AAPCS64 replaces it with a
  pointer to a caller copy). Confirmed: the body reads `[x0+0x14]` /`[x0+0x1c]`.
- **x1** — `const char *operation`.
- **w2** — the `sandbox_filter_type` enum.
- **variadic args** — on the stack, starting at the **incoming sp**
  (`x2 = x29+0x10 = sp_on_entry` is the va_list base). Apple's arm64 ABI puts
  all variadic arguments on the stack, so for a `mach-lookup` /
  `SANDBOX_FILTER_GLOBAL_NAME` check the one service-name string is the first
  stack slot.

The source signature is therefore
`int sandbox_check_by_audit_token(audit_token_t, const char *operation,
enum sandbox_filter_type, ...)`.

### Why forwarding is the hazard, and the safe shape

The number of variadic args varies by operation, so a C interpose cannot
forward the tail with `real(token, op, filter)` — that drops every variadic
argument, and non-target calls (every other sandbox check launchd makes)
would be evaluated with a garbage name. The forward has to preserve the
incoming stack and x0–x2 untouched.

The safe shape is an **assembly tail-call trampoline**, not a C function: on
entry it compares `operation` against `mach-lookup` and the first stack arg
against the one service name; on a match it returns 0; otherwise it restores
sp and x0–x2 to their entry values and `b`s to the real function. Because the
incoming sp is not disturbed, the real function's va_list still points at the
original stack args and the tail forwards perfectly. The compares must run on
a frame of the trampoline's own (saving x0–x2/lr across the `strcmp` calls),
torn down exactly before the branch.

This is still pid-1 code: a fault here crash-loops launchd and the guest does
not boot. It needs the trampoline written against this ABI and a boot test on
a throwaway 27.0 VM before it goes anywhere near a VM that matters. It is the
owner's call whether to take that surface on, and the permission system gates
the write.

## Validation status

- **Verified:** the kernel build and its Sandbox kext; the service/entitlement
  absent from the collection vs. the sibling and old-volume services present;
  iOS 27 shipping no userland profile collection; audiomxd registering the
  service; the live denial and dead slider; the exception-entitlement fix
  deployed with the name confirmed in SpringBoard's DER and the denial unchanged;
  Campo re-signed the identical way with its exceptions honoured.
- **Inferred:** that SpringBoard's platform profile does not apply
  exception-derived mach-lookup rules (behavioural, not bytecode-proven).
- **Confirmed (2026-10-04):** the enforcement point for option 1 is launchd
  itself. The guest's `/sbin/launchd` (iOS 27) imports
  `_sandbox_check_by_audit_token` and carries the `mach-lookup` string, so the
  service-lookup check is made in launchd's own binary — not in libxpc (which
  imports neither) and not only in the kernel. (`strings` on a shared-cache
  dylib extracted with `ipsw dyld extract` does not see the sandbox
  operation-name table — control names like `file-read-data` are absent too —
  so the earlier libxpc check was inconclusive, not negative.) The
  `sandbox_check_by_audit_token` ABI is recorded above.
- **Implemented (2026-10-04), pending boot test:** option 1 is written in
  `VPhoneGuestComponents/LaunchHook/launchdhook-vphone.c` as a C interpose of
  `sandbox_check_by_audit_token`. The call site was read first: all 21 calls in
  the guest's `/sbin/launchd` pass zero or one variadic argument (the name, at
  the incoming sp), so a C variadic interpose that reads one argument and
  forwards it reconstructs every call faithfully — the hand-written tail-call
  trampoline is not needed. The interpose returns allow (0) only for
  `operation == "mach-lookup"`, filter `GLOBAL_NAME`/`LOCAL_NAME` (2/3, which
  guarantee a valid name string), and name `== avvolumeclient.xpc`; every other
  check forwards to the real function (dyld does not interpose the defining
  image's own call, as the existing `posix_spawn`/`memorystatus_control`
  interposes in the same file rely on). It logs each allow to
  `/var/mobile/Library/Caches/vphone-launchdhook-sandbox.log`. Built and the
  `__interpose` section and the `sandbox_check_by_audit_token` import were
  verified. **Boot-tested on `mictest-iphone`:** the guest boots, the allow is
  logged, and the slider tracks a drag (0.59 → 0 → 0.62). The code and its
  commit message are the record of how it works.
- **Not done:** any working fix — options 1/2 need live validation on a VM the
  owner controls, on surfaces (pid-1 interpose / kernel sandbox) that brick boot
  if wrong.

### Recommended next step

Implement option 1 in `launchdhook-vphone.c`, confirming the live
`sandbox_check_by_audit_token` signature and the operation/filter constants
first, then boot-test on a throwaway 27.0 VM: open Control Center, confirm no
`Protobox … deny(1) mach-lookup …avvolumeclient.xpc`, and that the slider tracks
and `active_volume` changes — and that launchd/SpringBoard stay healthy.
