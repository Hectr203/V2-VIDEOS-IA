/*
 * vphoned_apfs — list and delete APFS snapshots of a mounted volume.
 *
 * fs_snapshot_list reads the snapshots of the volume a directory descriptor
 * is on, in getattrlistbulk's packed format; fs_snapshot_delete removes one
 * by name. The kernel lets a root caller holding a vfs snapshot entitlement
 * (vphoned carries com.apple.private.vfs.snapshot) delete a snapshot that
 * is not the volume's root or revert target and is not mounted.
 *
 * Both return 0 or an errno value. Which snapshot may be deleted is decided
 * in Swift (GuestSnapshotPolicy); this file does no filtering.
 * Research/Guest/template_snapshot_deletion.md has the evidence.
 */

#import "Include/VphonedNative.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/attr.h>
#include <sys/snapshot.h>
#include <unistd.h>

#define VP_APFS_LIST_BUFFER (64 * 1024)

// MARK: - Parsing

void vp_apfs_snapshot_names_free(char **names, int count) {
    if (!names) return;
    for (int index = 0; index < count; index++) free(names[index]);
    free(names);
}

static bool vp_apfs_contains(char **names, int count, const char *name) {
    for (int index = 0; index < count; index++) {
        if (strcmp(names[index], name) == 0) return true;
    }
    return false;
}

int vp_apfs_snapshot_parse(const char *buffer, size_t size, int entries, char ***names, int *count, int *added) {
    if (!buffer || !names || !count || !added) return EINVAL;
    *added = 0;
    const char *entry = buffer;
    const char *end = buffer + size;
    for (int index = 0; index < entries; index++) {
        // Each entry: its length, the attributes returned, then an
        // attrreference whose offset is relative to the reference itself.
        if ((size_t)(end - entry) < sizeof(uint32_t) + sizeof(attribute_set_t)) break;
        uint32_t length;
        memcpy(&length, entry, sizeof(length));
        if (length < sizeof(uint32_t) + sizeof(attribute_set_t) || length > (size_t)(end - entry)) break;
        attribute_set_t returned;
        memcpy(&returned, entry + sizeof(uint32_t), sizeof(returned));
        const char *field = entry + sizeof(uint32_t) + sizeof(attribute_set_t);
        const char *entryEnd = entry + length;
        if ((returned.commonattr & ATTR_CMN_NAME) && (size_t)(entryEnd - field) >= sizeof(attrreference_t)) {
            attrreference_t reference;
            memcpy(&reference, field, sizeof(reference));
            const char *name = field + reference.attr_dataoffset;
            if (reference.attr_dataoffset >= (int32_t)sizeof(attrreference_t) && reference.attr_length > 1
                && name < entryEnd && reference.attr_length <= (size_t)(entryEnd - name)
                && name[reference.attr_length - 1] == '\0' && !vp_apfs_contains(*names, *count, name)) {
                char *copy = strdup(name);
                char **grown = copy ? realloc(*names, sizeof(char *) * (size_t)(*count + 1)) : NULL;
                if (!grown) {
                    free(copy);
                    return ENOMEM;
                }
                *names = grown;
                (*names)[(*count)++] = copy;
                (*added)++;
            }
        }
        entry = entryEnd;
    }
    return 0;
}

// MARK: - Listing

int vp_apfs_snapshot_list(const char *mount, char ***names, int *count) {
    if (!mount || !names || !count) return EINVAL;
    *names = NULL;
    *count = 0;
    int directory = open(mount, O_RDONLY | O_DIRECTORY, 0);
    if (directory < 0) return errno ?: EIO;

    struct attrlist attributes;
    memset(&attributes, 0, sizeof(attributes));
    attributes.bitmapcount = ATTR_BIT_MAP_COUNT;
    attributes.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_NAME;

    // Each call continues where the last one stopped and returns 0 at the
    // end. A batch that adds no new name ends the walk as well, so a kernel
    // that answers every call from the start cannot loop forever.
    char *buffer = malloc(VP_APFS_LIST_BUFFER);
    int status = buffer ? 0 : ENOMEM;
    char **list = NULL;
    int total = 0;
    for (int batch = 0; status == 0 && batch < 64; batch++) {
        int entries = fs_snapshot_list(directory, &attributes, buffer, VP_APFS_LIST_BUFFER, 0);
        if (entries < 0) {
            status = errno ?: EIO;
            break;
        }
        if (entries == 0) break;
        int added = 0;
        status = vp_apfs_snapshot_parse(buffer, VP_APFS_LIST_BUFFER, entries, &list, &total, &added);
        if (added == 0) break;
    }
    free(buffer);
    close(directory);
    if (status != 0) {
        vp_apfs_snapshot_names_free(list, total);
        return status;
    }
    *names = list;
    *count = total;
    return 0;
}

// MARK: - Deletion

int vp_apfs_snapshot_delete(const char *mount, const char *name) {
    if (!mount || !name || !name[0]) return EINVAL;
    int directory = open(mount, O_RDONLY | O_DIRECTORY, 0);
    if (directory < 0) return errno ?: EIO;
    int status = fs_snapshot_delete(directory, name, 0) == 0 ? 0 : (errno ?: EIO);
    close(directory);
    return status;
}
