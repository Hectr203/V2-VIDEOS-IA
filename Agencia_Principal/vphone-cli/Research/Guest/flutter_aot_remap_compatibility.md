# Flutter AOT callback remap compatibility

## Failure and scope

On a tested iPadOS 26.6.2 guest using cloudOS 26.4, an executable page remap
returned success and RX protection while the destination was actually read-only.
Executing a callback in that mapping caused `CODESIGNING / Invalid Page`.
A crash reporter could subsequently fail with `EXC_GUARD`, masking the first fault.

A standalone signed Swift probe reproduced the mismatch without Flutter or an
injected script. Disabling optional tweaks for that probe did not change it.
`vm_remap_new` and changing the destination to RX afterwards did not recover it.
Allocating RW memory, copying bytes, then setting RX did work. The precise
responsible kernel-policy branch has not been established; this change is a
bounded guest compatibility fallback, not a kernel fix.

## Runtime behavior

SystemHook provides the interpose before application initialization. It first
calls the original `vm_remap` and leaves all normal outcomes unchanged. Repair
requires every condition below:

- The executable and both images resolve to the same canonical `.app` bundle.
- The source is its `Frameworks/App.framework/App`; the caller is its
  `Frameworks/Flutter.framework/Flutter`.
- Same-task, private-copy, fixed-overwrite remap of 32 KiB, with source image
  offset 16 KiB: the observed AOT callback layout, not an arbitrary code copy.
- Original success with reported RX/current and RWX/maximum; source actually RX.
- An exact destination mapping that is read-only with maximum RW, and no overlap
  with the source.

The fallback atomically overwrites the newly created, not-yet-published target
with private RW memory, honors inheritance, copies the bytes, changes it to RX,
and verifies the result. It never requests simultaneous writable/executable
access and does not change signing or kernel protection policy. Allocation,
inheritance or protection failures propagate as errors with cleanup of owned
replacement mappings. Unrecognized layouts continue through the native path.

This interpose is linked into the existing SystemHook component; it needs no
new firmware patch selector or public command. An old host bundle will resync
its old library on guest reconnect, so the guest must be bound to the bundle
containing the fix to keep it across restarts.

## Validation

Host checks:

```sh
make -C VPhoneGuestComponents test-flutter-remap test-flutter-remap-repair test-injection-environment
make -C VPhoneGuestComponents build-executable-remap-probe
```

`ExecutableRemapProbe` is a standalone guest test binary, not shipped runtime
code. It duplicates its own constant-returning function. Default mode reports
the permission mismatch and exits3 without executing a non-executable mapping;
`--copy` exercises the alternate path and expects42. Stage and run it only on
an existing authorized test guest.

The core fallback was exercised with a Flutter AOT guest workload: two cold
launches remained alive for60seconds each, followed by another60second same-PID
check after a full VM restart and bundle rebinding. The interface rendered
normally and the deployed library hash remained unchanged after reconnect.

That live acceptance used an earlier application-filtered prototype. This PR
replaces that filter with canonical same-bundle image checks, covered by host
positive/negative tests. Broad Flutter/application/version coverage and live
acceptance of that generalized selector are still pending. Keep this change
in draft until that additional coverage is reviewed.
