import Darwin

/// Standalone guest probe: no app dependencies, injected scripts or kernel writes.
/// The default mode reports the remap mismatch without executing an NX mapping.
/// --copy exercises the RW-copy-then-RX alternative.
@_cdecl("remap_probe_marker") public func remapProbeMarker() -> Int32 {
    42
}

func protection(at value: vm_address_t) -> vm_prot_t? {
    var address = value, size: vm_size_t = 0
    var info = vm_region_basic_info_data_64_t()
    var count = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.size / 4)
    var object: mach_port_t = 0
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            vm_region_64(mach_task_self_, &address, &size, VM_REGION_BASIC_INFO_64, $0, &count, &object)
        }
    }
    if object != 0 {
        mach_port_deallocate(mach_task_self_, object)
    }
    guard result == KERN_SUCCESS, address <= value, value - address < size else { return nil }
    return info.protection
}

let marker: @convention(c) () -> Int32 = remapProbeMarker
let source = vm_address_t(UInt(bitPattern: unsafeBitCast(marker, to: UnsafeRawPointer.self)))
let page = source & ~vm_address_t(vm_page_size - 1)
let offset = source - page
let rx = VM_PROT_READ | VM_PROT_EXECUTE
var target: vm_address_t = 0, current: vm_prot_t = 0, maximum: vm_prot_t = 0
print("original marker", marker(), "protection", protection(at: source) ?? -1)
let result: kern_return_t
if CommandLine.arguments.contains("--copy") {
    result = vm_allocate(mach_task_self_, &target, vm_size_t(vm_page_size), VM_FLAGS_ANYWHERE)
    if result == KERN_SUCCESS {
        memcpy(UnsafeMutableRawPointer(bitPattern: UInt(target))!, UnsafeRawPointer(bitPattern: UInt(page))!, Int(vm_page_size))
        let changed = vm_protect(mach_task_self_, target, vm_size_t(vm_page_size), 0, rx)
        print("copy protection result", changed)
    }
} else {
    result = vm_remap(mach_task_self_, &target, vm_size_t(vm_page_size), 0, VM_FLAGS_ANYWHERE,
                      mach_task_self_, page, 1, &current, &maximum, VM_INHERIT_NONE)
    print("remap result", result, "reported protections", current, maximum)
}

guard result == KERN_SUCCESS else { exit(2) }
let actual = protection(at: target)
print("actual protection", actual ?? -1)
guard actual == rx else {
    vm_deallocate(mach_task_self_, target, vm_size_t(vm_page_size))
    exit(3)
}

let copied = unsafeBitCast(UnsafeRawPointer(bitPattern: UInt(target + offset))!, to: (@convention(c) () -> Int32).self)
let answer = copied()
print("copied marker", answer)
vm_deallocate(mach_task_self_, target, vm_size_t(vm_page_size))
exit(answer == 42 ? 0 : 4)
