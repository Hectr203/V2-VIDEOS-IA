// vphone-escalator — let an ad-hoc signed binary carry Apple-private
// entitlements, without writing a single byte into anyone's __TEXT.
//
// This is the project's copy of github.com/Lakr233/amfi-allow (MIT), built
// by its own Xcode target for arm64e. Keep it in step with upstream.
//
// It exists because vphone-vm is the one binary here that holds
// com.apple.private.* entitlements, and amfid refuses it. The bundled helper
// allows the binaries the current build just produced. Their
// cdhashes change every time they are signed, so that is a per-build step, not
// a once-per-machine one.
//
// Build with the VPhoneEscalator Xcode target (arm64e, then ad-hoc signed
// during bundle staging). No Python or LLDB is needed.
//
// Source layout:
//
//   VPhoneEscalator.c  this comment and main()
//   Escalator.h        shared paths, keys, globals, and declarations
//   AMFIDTask.c        the manager class and singleton slot, attaching to
//                      amfid, and reading and writing its memory
//   Requirements.c     cdhashes and the requirement strings built from them
//   Preferences.c      the coderequirements preference and its entries
//   Commands.c         the status, allow, and off verbs
//
// ---------------------------------------------------------------------------
// Why this exists
// ---------------------------------------------------------------------------
// An ad-hoc signed binary carrying com.apple.private.* entitlements is refused
// by amfid, so the kernel kills it at exec. The usual answers rewrite amfid's
// code:
//
//   * debugger-based tools break on -[AMFIPathValidator_macos
//     validateWithError:] and patch the result register. LLDB's default is a
//     software breakpoint, which plants BRK in amfid's __TEXT.
//   * patchers overwrite the ldrb that loads _isValid in that method's
//     epilogue.
//
// Both produce a dirty, unsigned executable page in amfid. On a host with
// vm.cs_system_enforcement = 1 the kernel validates that page on the next
// fault and kills amfid: CODESIGNING / "Invalid Page". The sysctl is read-only
// at runtime, so no amount of care makes "patch the code" survive it.
//
// ---------------------------------------------------------------------------
// What this does instead
// ---------------------------------------------------------------------------
// AMFI already ships the feature we want. -[AMFIRequirementsManager
// checkCodeRequirementsPreferenceUnsynchronized] reads
//
//     /Library/Preferences/com.apple.security.coderequirements.plist
//
// and takes two keys out of it:
//
//     Entitlements               a code requirement string; it *replaces*
//                                _restrictedRequirement, which is the
//                                requirement a binary must satisfy to be
//                                allowed to carry restricted entitlements.
//     AllowUnsafeDynamicLinking  a BOOL; it becomes the validator's
//                                _shouldUnrestrict, i.e. processes stop being
//                                marked restricted, so DYLD_INSERT_LIBRARIES
//                                is honoured again.
//
// -[AMFIPathValidator_macos validateWithError:] calls
// SecStaticCodeCheckValidityWithErrors(code, 6, restrictedRequirement, &err)
// on exactly that requirement. So `cdhash H"..."` in the Entitlements key is a
// per-binary allowlist, evaluated by Apple's own code.
//
// The whole preference is gated on one BOOL ivar:
//
//     _isRunningInternalBuild = (csr_check(CSR_ALLOW_APPLE_INTERNAL) == 0)
//
// set once in -[AMFIRequirementsManager init] and read in exactly four places,
// all of them about this preference. (Its only other reader, the validator's
// init, uses it to consult the sysctl security.mac.amfi.qa_root_certs_allowed,
// which is 0 on a production machine.)
//
// So this tool writes ONE BYTE: that ivar, in the singleton, on amfid's heap.
//
//   * The singleton pointer lives in a static slot inside the dyld shared
//     cache, at the same address in every process. This tool finds the slot by
//     decoding +[AMFIRequirementsManager sharedManager] and testing each
//     address it loads against the singleton this process just created --
//     nothing is hardcoded, and a layout change is a refusal, not a wild write.
//   * The target is malloc'd heap. No mach_vm_protect, no copy-on-write of a
//     shared-cache page, no executable memory, nothing for the code-signing
//     monitor to object to. vm.cs_system_enforcement is irrelevant.
//   * The ivar offset comes from the live ObjC runtime, never a constant.
//
// It needs root and task_for_pid, i.e. SIP with debugging restrictions off --
// the same prerequisite the old tools had, and the same one that makes amfid
// honour the preference at all (see the csr_check note above).
//
// `off` removes only hashes this tool added, then restarts amfid. It preserves
// the preference and every other value, including AllowUnsafeDynamicLinking.
#include "Escalator.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--nop") == 0) return 0; // the amfid poke

    setvbuf(stdout, NULL, _IOLBF, 0); // keep stdout in step with stderr
    const char *self_path = argv[0];
    const char *verb = argc > 1 ? argv[1] : "status";

    if (strcmp(verb, "status") == 0) {
        report(self_path);
        return 0;
    }
    if (strcmp(verb, "off") == 0) {
        if (geteuid() != 0) { fprintf(stderr, "error: This command needs root. Run it with sudo.\n"); return 1; }
        return cmd_off(self_path);
    }
    if (strcmp(verb, "allow") == 0) {
        if (geteuid() != 0) { fprintf(stderr, "error: This command needs root. Run it with sudo.\n"); return 1; }
        int hold = 0, first = 2;
        if (argc > 3 && strcmp(argv[2], "--hold") == 0) {
            hold = atoi(argv[3]);
            first = 4;
        }
        if (first >= argc) {
            fprintf(stderr, "error: Specify at least one binary to allow.\n");
            return 2;
        }
        return cmd_allow(self_path, argc - first, argv + first, hold);
    }

    fprintf(stderr,
            "usage:\n"
            "  vphone-escalator status\n"
            "  sudo vphone-escalator allow [--hold N] <binary> [<binary>...]\n"
            "  sudo vphone-escalator off\n"
            "\n"
            "Allow both signed vphone-vm copies after each build.\n");
    return 2;
}
