/*
 * vphoned_power — shut the guest down.
 *
 * reboot3 hands the request to launchd, which stops every service, unmounts
 * the volumes and then halts the kernel. The flags are the ones
 * `launchctl reboot halt` passes: a full reboot with RB_HALT set. The host
 * sees the halt as the virtual machine stopping.
 *
 * icli's `requestReboot` covers the restart kinds; it has no halt.
 */

#import "Include/VphonedNative.h"

#include <errno.h>

extern int reboot3(uint64_t flags, ...);
#define RB2_FULLREBOOT 0x8000000000000000ULL
// <sys/reboot.h> is not in the iOS SDK.
#define RB_HALT 0x08

int vp_system_halt(void) {
    errno = 0;
    if (reboot3(RB2_FULLREBOOT | RB_HALT, 0) == 0) return 0;
    return errno ?: EIO;
}
