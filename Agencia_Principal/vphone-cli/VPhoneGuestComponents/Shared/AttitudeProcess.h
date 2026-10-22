#ifndef VPHONE_ATTITUDE_PROCESS_H
#define VPHONE_ATTITUDE_PROCESS_H

#include <string.h>

// .app paths also include SpringBoard and other system UI services. A
// simulated app pose must not drive their motion effects or native sensors.
static inline int vpAttitudeAllowsProcess(const char *path) {
    if (!path || path[0] != '/')
        return 0;
    if (strstr(path, "/System/Library/") != NULL)
        return 0;
    const char *springboard = "/SpringBoard.app/SpringBoard";
    size_t length = strlen(path), suffixLength = strlen(springboard);
    return length < suffixLength || strcmp(path + length - suffixLength, springboard) != 0;
}

#endif
