#include <mach/mach.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
static unsigned char targetBytes[32768], sourceBytes[32768];
static int allocateError, inheritError, protectError, queryProtection, wrongAddress, frees, copies;
static kern_return_t testAllocate(vm_map_t task, vm_address_t *address, vm_size_t size, int flags) {
 (void)task;assert(size==32768);assert(flags==(VM_FLAGS_FIXED|VM_FLAGS_OVERWRITE));
 if(wrongAddress)*address+=32768;
 return allocateError;
}
static kern_return_t testInherit(vm_map_t task, vm_address_t address, vm_size_t size, vm_inherit_t inheritance) {
 (void)task;(void)address;assert(size==32768);assert(inheritance==VM_INHERIT_NONE);return inheritError;
}
static kern_return_t testProtect(vm_map_t task, vm_address_t address, vm_size_t size, boolean_t maximum, vm_prot_t protection) {
 (void)task;(void)address;assert(size==32768);assert(!maximum);assert(protection==(VM_PROT_READ|VM_PROT_EXECUTE));copies++;return protectError;
}
static kern_return_t testDeallocate(vm_map_t task, vm_address_t address, vm_size_t size) {
 (void)task;(void)address;assert(size==32768);frees++;return KERN_SUCCESS;
}
static kern_return_t testRegion(vm_map_read_t task, vm_address_t *address, vm_size_t *size, vm_region_flavor_t flavor,
 vm_region_info_t info, mach_msg_type_number_t *count, mach_port_t *object) {
 (void)task;(void)address;(void)count;assert(flavor==VM_REGION_BASIC_INFO_64);*size=32768;*object=MACH_PORT_NULL;
 vm_region_basic_info_64_t output=(vm_region_basic_info_64_t)info;memset(output,0,sizeof(*output));output->protection=queryProtection;output->max_protection=7;return KERN_SUCCESS;
}
#define vm_allocate testAllocate
#define vm_inherit testInherit
#define vm_protect testProtect
#define vm_deallocate testDeallocate
#define vm_region_64 testRegion
#define VP_REMAP_FIX_NO_INTERPOSE
#include "../FlutterRemapFix/libflutterremapfix.c"
static void reset(void){allocateError=inheritError=protectError=wrongAddress=frees=copies=0;queryProtection=5;memset(targetBytes,0,sizeof(targetBytes));memset(sourceBytes,42,sizeof(sourceBytes));}
static int perform(void){return repair((vm_address_t)targetBytes,(vm_address_t)sourceBytes,32768,VM_INHERIT_NONE);}
int main(void){
 reset();assert(perform()==0);assert(memcmp(targetBytes,sourceBytes,32768)==0);assert(copies==1&&frees==0);
 reset();allocateError=KERN_NO_SPACE;assert(perform()==KERN_NO_SPACE);assert(copies==0&&frees==0&&targetBytes[0]==0);
 reset();wrongAddress=1;assert(perform()==KERN_FAILURE);assert(copies==0&&frees==1);
 reset();inheritError=KERN_INVALID_ARGUMENT;assert(perform()==KERN_INVALID_ARGUMENT);assert(copies==0&&frees==1);
 reset();protectError=KERN_PROTECTION_FAILURE;assert(perform()==KERN_PROTECTION_FAILURE);assert(frees==1);
 reset();queryProtection=VM_PROT_READ;assert(perform()==KERN_PROTECTION_FAILURE);assert(frees==1);
 puts("FlutterRemapRepairTests: atomic overwrite, exact copy, RX-only transition and failure cleanup passed");
}
