// MISFixDetour.h — replace a function, not its call sites.
//
// `__DATA,__interpose` rewrites the places that *call* a symbol, in the images
// dyld links. It never reaches a call made from one shared-cache image to
// another, which is measured in MISFixDeviceIdentity.c and is the reason an
// interpose cannot touch installd: `MobileInstallation → libmis →
// libMobileGestalt` happens entirely inside the cache.
//
// A detour rewrites the *callee*. The first four instructions of the target
// become an absolute jump to the replacement, and those four instructions are
// moved to a trampoline that jumps back. Every caller is then redirected,
// wherever it lives, because there is only one copy of the function.
//
// What it costs, and what it therefore refuses to guess about:
//
//   - The target's page must be made writable. The cache is mapped
//     read-execute and shared with every process, so the only way in is
//     copy-on-write. Measured working on test-26.4 (2026-09-30): the page
//     splits into a private copy and the write lands. Nothing on disk changes
//     and no other process sees it, which is the difference between this and
//     the cache patch that left a 27.0 guest unable to boot (issue #532).
//   - The displaced instructions must survive being moved. `adr` and `adrp`
//     are rewritten to materialise the same absolute address, and an
//     unconditional `b` becomes an absolute jump. Anything else PC-relative —
//     `bl`, `b.cond`, `cbz`, `tbz`, a literal load — is **refused**, because a
//     wrong relocation is a corrupted daemon and a refusal is a log line.
//   - The target must be at least four instructions long. A function that
//     returns or jumps away sooner is *shorter* than the patch, so writing it
//     would scribble on whoever follows. A terminator in the first three words
//     is refused for that reason.
//
// The target is given as an address, never as a name, and that is not a
// stylistic choice. dyld applies interposing to `dlsym` — measured on
// test-26.4 even for a lookup scoped to a handle on the owning image, which
// came back inside libmisfix.dylib. What dyld does not interpose is the
// interposing image's own imports, so the way to name a function here is to
// declare it, call `&` on it from this dylib, and let the linker bind it.
//
// Install detours from a constructor. Four words cannot be replaced atomically,
// so a thread already executing the target's prologue is a hazard; at image
// load the process has not begun serving and that is as close to safe as this
// gets.

#ifndef MISFIX_DETOUR_H
#define MISFIX_DETOUR_H

/// Why a detour was not installed. `MISFixDetourOK` is zero.
typedef enum {
    MISFixDetourOK = 0,
    /// The target address is NULL — the symbol did not bind.
    MISFixDetourNoTarget,
    /// A displaced instruction is PC-relative in a way this does not rewrite.
    MISFixDetourUnrelocatable,
    /// The target returns or jumps away inside the four words the jump needs,
    /// so it is too short to detour.
    MISFixDetourTooShort,
    /// No executable memory could be obtained for the trampoline.
    MISFixDetourNoTrampoline,
    /// The target's page could not be made writable.
    MISFixDetourPageReadOnly,
    /// The bytes did not read back as written.
    MISFixDetourWriteFailed,
} MISFixDetourResult;

/// A sentence for the log, never NULL.
const char *MISFixDetourDescribe(MISFixDetourResult result);

/// Point `target` at `replacement`.
///
/// On success `*original` receives a pointer that behaves as the untouched
/// function did, already signed for an arm64e indirect call, and the
/// replacement calls through it for everything it does not mean to change.
/// On failure nothing is written and `*original` is left alone.
///
/// `label` names the target in the log and is not otherwise used.
MISFixDetourResult MISFixDetour(
    const char *label,
    void *target,
    void *replacement,
    void **original
);

#endif
