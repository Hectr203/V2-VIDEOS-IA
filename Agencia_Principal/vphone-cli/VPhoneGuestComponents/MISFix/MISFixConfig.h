// MISFixConfig.h — the hook's one configuration file.
//
// `/usr/lib/libmisfix.plist`, beside the dylib, so a process that can load the
// hook can always read its settings: installd and misagent are sandboxed, and
// /usr/lib is the one directory both already reach.
//
// Keys, all optional. An absent or unreadable file leaves every behaviour off,
// which is the same as not injecting the hook at all.
//
//     UniqueDeviceID  (string)  The UDID to answer MobileGestalt with. Set it
//                               to a device already registered with a team and
//                               that team's profiles install on this guest.
//                               Empty or absent: the guest answers with its
//                               own. Reaches misagent only — installd's own
//                               check is made inside the shared cache, where
//                               an interpose does not land, so this does not
//                               by itself make an Xcode install succeed. See
//                               "How far this reaches" in
//                               MISFixDeviceIdentity.c.
//     LogQueries      (bool)    Log every MobileGestalt query this hook sees.
//                               Off by default: these daemons are asked a lot.
//                               For finding out whether a process asks through
//                               the symbol at all, which is not observable from
//                               outside — see MISFixDeviceIdentity.c.

#ifndef MISFIX_CONFIG_H
#define MISFIX_CONFIG_H

#include <CoreFoundation/CoreFoundation.h>

/// The configured UDID, or NULL when none is set.
///
/// Borrowed — the caller must not release it. Re-read when the file's
/// modification time or size changes, so editing the plist takes effect on the
/// next query without restarting anything.
CFStringRef MISFixCopyConfiguredDeviceIdentifier(void);

/// Whether `key` is set to true in the configuration.
///
/// Reads the same file, through the same staleness check, as
/// ``MISFixCopyConfiguredDeviceIdentifier``. False when the key is absent, not
/// a boolean, or no configuration can be read.
int MISFixConfiguredFlag(CFStringRef key);

/// Log `format` under `LogQueries`, prefixed so one predicate finds every line
/// this dylib writes, from whichever process is carrying it.
///
/// A no-op unless the flag is set.
void MISFixLog(const char *format, ...) __attribute__((format(printf, 1, 2)));

/// Log `format` whatever the configuration says, with the same prefix.
///
/// For a diagnostic that carries its own switch and would otherwise need two
/// flags set to say anything.
void MISFixNote(const char *format, ...) __attribute__((format(printf, 1, 2)));

/// The name of the image `address` belongs to — the last path component of the
/// Mach-O that contains it, or `"?"` when nothing claims it.
///
/// Always safe to print: the result is a pointer into dyld's own image name,
/// or a static string, never allocated.
///
/// This exists to tell two very different worlds apart in one log line. A
/// `__DATA,__interpose` replacement is applied to a *call site*, and a call
/// made from inside the shared cache into another cache image may never reach
/// it. So "installd never logged a query" has two readings — the daemon does
/// not ask, or the daemon's frameworks ask past us — and the caller's image is
/// what separates them: `installd` means the main executable asked and the
/// interpose works, anything under the cache means it reaches cache-to-cache
/// calls too.
const char *MISFixCallerImage(const void *address);

/// Whether this process's executable is named `name`, compared on the last
/// path component.
///
/// The same dylib is inserted into installd, misagent and SpringBoard, and not
/// every hook belongs in all three: MobileInstallation's policy is installd's
/// alone, and loading that framework into SpringBoard to swizzle it would
/// change a process the hook has no business in.
int MISFixProcessIs(const char *name);

/// Whether this is lockdownd or remoted, which carry the dylib only so the host
/// is told the configured UDID. They never evaluate a signature, so the MIS
/// detours leave their copy of libmis alone.
int MISFixProcessOnlyNeedsIdentity(void);

/// The image of whoever called the function this appears in.
#define MISFixCaller() MISFixCallerImage(__builtin_return_address(0))

/// The flag every diagnostic in this dylib is behind.
#define kMISFixLogQueriesKey CFSTR("LogQueries")

#endif
