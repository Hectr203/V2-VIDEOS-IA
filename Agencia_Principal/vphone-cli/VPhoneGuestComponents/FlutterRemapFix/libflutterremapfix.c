#include "FlutterRemapPolicy.h"
#include <dlfcn.h>
#include <limits.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <os/log.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

static char executable[PATH_MAX];
static pthread_once_t executableOnce = PTHREAD_ONCE_INIT;
static _Atomic unsigned loggedRepairs;
static void readExecutable(void) {
    char path[PATH_MAX];
    uint32_t size = sizeof(path);
    if (_NSGetExecutablePath(path, &size) != 0 || !realpath(path, executable))
        executable[0] = 0;
}

static bool region(vm_address_t address, vm_size_t length, vm_prot_t *protection,
                   vm_prot_t *maximum, bool exact) {
    vm_address_t start = address;
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info = {0};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    kern_return_t result = vm_region_64(mach_task_self(), &start, &size,
        VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object);
    if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
    if (result != KERN_SUCCESS || start > address || address - start > size ||
        length > size - (address - start) || (exact && (start != address || size != length)))
        return false;
    *protection = info.protection;
    *maximum = info.max_protection;
    return true;
}

static kern_return_t repair(vm_address_t target, vm_address_t source, vm_size_t size, vm_inherit_t inheritance) {
    vm_address_t address = target;
    // The caller has not published this just-created mapping yet. Overwrite it
    // atomically, avoiding a deallocate/allocate race with other threads.
    kern_return_t result = vm_allocate(mach_task_self(), &address, size,
        VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE);
    if (result != KERN_SUCCESS) return result;
    if (address != target) {
        vm_deallocate(mach_task_self(), address, size);
        return KERN_FAILURE;
    }
    result = vm_inherit(mach_task_self(), target, size, inheritance);
    if (result != KERN_SUCCESS) { vm_deallocate(mach_task_self(), target, size); return result; }
    memcpy((void *)target, (const void *)source, size);
    result = vm_protect(mach_task_self(), target, size, false, VM_PROT_READ | VM_PROT_EXECUTE);
    vm_prot_t current = 0, maximum = 0;
    if (result == KERN_SUCCESS && (!region(target, size, &current, &maximum, false) ||
        current != (VM_PROT_READ | VM_PROT_EXECUTE))) result = KERN_PROTECTION_FAILURE;
    if (result != KERN_SUCCESS) vm_deallocate(mach_task_self(), target, size);
    return result;
}

static kern_return_t vpFlutterRemap(vm_map_t targetTask, vm_address_t *target,
    vm_size_t size, vm_address_t mask, int flags, vm_map_read_t sourceTask,
    vm_address_t source, boolean_t copy, vm_prot_t *current, vm_prot_t *maximum,
    vm_inherit_t inheritance) {
    // dyld does not apply an image's own interposition to its imports: this is
    // the original vm_remap, not recursion into this wrapper.
    kern_return_t result = vm_remap(targetTask, target, size, mask, flags,
        sourceTask, source, copy, current, maximum, inheritance);
    if (result != KERN_SUCCESS || !target || !current || !maximum ||
        *current != (VM_PROT_READ | VM_PROT_EXECUTE) || *maximum != VM_PROT_ALL ||
        targetTask != mach_task_self() || sourceTask != mach_task_self() ||
        size != 32768 || copy != 1 || flags != (VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE)) return result;

    pthread_once(&executableOnce, readExecutable);
    Dl_info sourceInfo = {0}, callerInfo = {0};
    char sourcePath[PATH_MAX], callerPath[PATH_MAX];
    if (!dladdr((void *)source, &sourceInfo) ||
        !dladdr(__builtin_return_address(0), &callerInfo) ||
        !sourceInfo.dli_fname || !callerInfo.dli_fname ||
        !realpath(sourceInfo.dli_fname, sourcePath) || !realpath(callerInfo.dli_fname, callerPath) ||
        !vpFlutterRemapCandidate(executable, sourcePath, callerPath,
            source - (uintptr_t)sourceInfo.dli_fbase, size, flags, copy, true)) return result;
    vm_prot_t sourceProtection = 0, sourceMaximum = 0, actual = 0, actualMaximum = 0;
    if (!region(source, size, &sourceProtection, &sourceMaximum, false) ||
        sourceProtection != (VM_PROT_READ | VM_PROT_EXECUTE) ||
        !region(*target, size, &actual, &actualMaximum, true) || actual != VM_PROT_READ || actualMaximum != (VM_PROT_READ | VM_PROT_WRITE) ||
        (*target <= source ? source - *target < size : *target - source < size)) return result;

    result = repair(*target, source, size, inheritance);
    if (result != KERN_SUCCESS) {
        os_log_error(OS_LOG_DEFAULT, "vphone Flutter remap repair failed: %{public}d", result);
        return result; // Never report success for an unusable mapping.
    }
    // Preserve the successful original result; actual current protection is RX.
    if (atomic_fetch_add(&loggedRepairs, 1) < 8)
        os_log(OS_LOG_DEFAULT, "vphone Flutter remap repaired: %{public}llu bytes, RW then RX",
            (unsigned long long)size);
    return KERN_SUCCESS;
}

#ifndef VP_REMAP_FIX_NO_INTERPOSE
__attribute__((used, section("__DATA,__interpose")))
static const struct { const void *replacement; const void *original; } interposition = {
    (const void *)&vpFlutterRemap, (const void *)&vm_remap
};

#endif
