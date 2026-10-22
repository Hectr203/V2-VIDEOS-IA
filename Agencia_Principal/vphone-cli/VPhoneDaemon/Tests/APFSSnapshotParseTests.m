#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/attr.h>
#import "../Native/Include/VphonedNative.h"

// Feeds vp_apfs_snapshot_parse hand-built fs_snapshot_list batches. Nothing
// here lists or deletes a real snapshot: the runner never calls
// vp_apfs_snapshot_list or vp_apfs_snapshot_delete on the Mac.

static size_t appendEntry(char *buffer, size_t offset, const char *name, bool withName, int32_t dataOffset) {
    size_t nameLength = strlen(name) + 1;
    size_t length = sizeof(uint32_t) + sizeof(attribute_set_t) + sizeof(attrreference_t) + nameLength;
    length = (length + 7) & ~(size_t)7;
    char *entry = buffer + offset;
    memset(entry, 0, length);
    uint32_t stored = (uint32_t)length;
    memcpy(entry, &stored, sizeof(stored));
    attribute_set_t returned = {0};
    returned.commonattr = withName ? ATTR_CMN_NAME : 0;
    memcpy(entry + sizeof(uint32_t), &returned, sizeof(returned));
    attrreference_t reference = {.attr_dataoffset = dataOffset, .attr_length = (u_int32_t)nameLength};
    char *field = entry + sizeof(uint32_t) + sizeof(attribute_set_t);
    memcpy(field, &reference, sizeof(reference));
    memcpy(field + sizeof(reference), name, nameLength);
    return offset + length;
}

static int checks, failures;
static void check(bool condition, const char *message) {
    checks++;
    if (!condition) {
        failures++;
        printf("FAIL: %s\n", message);
    }
}

int main(void) {
    char buffer[4096];
    char **names = NULL;
    int count = 0, added = 0;
    const int32_t direct = (int32_t)sizeof(attrreference_t);

    size_t size = appendEntry(buffer, 0, "com.apple.os.update-4EC2ECB9", true, direct);
    size = appendEntry(buffer, size, "orig-fs.disabled.rn-4EC2ECB9", true, direct);
    check(vp_apfs_snapshot_parse(buffer, size, 2, &names, &count, &added) == 0, "parses a batch");
    check(count == 2 && added == 2, "two names");
    check(count == 2 && strcmp(names[0], "com.apple.os.update-4EC2ECB9") == 0, "first name");
    check(count == 2 && strcmp(names[1], "orig-fs.disabled.rn-4EC2ECB9") == 0, "second name");

    // The same batch again adds nothing: the listing loop stops on that.
    check(vp_apfs_snapshot_parse(buffer, size, 2, &names, &count, &added) == 0 && added == 0 && count == 2,
          "repeated batch adds nothing");

    // Malformed entries are skipped or end the batch, never read past it.
    size = appendEntry(buffer, 0, "no-name-attribute", false, direct);
    size = appendEntry(buffer, size, "bad-offset", true, 4096);
    size = appendEntry(buffer, size, "negative-offset", true, -64);
    size_t valid = appendEntry(buffer, size, "orig-fs.disabled.rn-7A11", true, direct);
    check(vp_apfs_snapshot_parse(buffer, valid, 4, &names, &count, &added) == 0 && added == 1 && count == 3,
          "skips entries without a usable name");
    check(count == 3 && strcmp(names[2], "orig-fs.disabled.rn-7A11") == 0, "keeps the valid entry");

    // More entries claimed than the buffer holds, and a truncated entry.
    check(vp_apfs_snapshot_parse(buffer, valid, 50, &names, &count, &added) == 0 && added == 0,
          "entry count beyond the buffer");
    check(vp_apfs_snapshot_parse(buffer, 10, 1, &names, &count, &added) == 0 && added == 0, "truncated header");
    uint32_t huge = 1u << 30;
    memcpy(buffer, &huge, sizeof(huge));
    check(vp_apfs_snapshot_parse(buffer, valid, 1, &names, &count, &added) == 0 && added == 0, "oversized entry length");
    uint32_t zero = 0;
    memcpy(buffer, &zero, sizeof(zero));
    check(vp_apfs_snapshot_parse(buffer, valid, 4, &names, &count, &added) == 0 && added == 0, "zero entry length");

    // A name without its terminator is refused.
    size = appendEntry(buffer, 0, "unterminated", true, direct);
    buffer[sizeof(uint32_t) + sizeof(attribute_set_t) + sizeof(attrreference_t) + strlen("unterminated")] = 'x';
    check(vp_apfs_snapshot_parse(buffer, size, 1, &names, &count, &added) == 0 && added == 0, "unterminated name");

    check(vp_apfs_snapshot_parse(NULL, 0, 1, &names, &count, &added) == EINVAL, "null buffer");
    vp_apfs_snapshot_names_free(names, count);

    printf("%d/%d parser checks passed\n", checks - failures, checks);
    return failures == 0 ? 0 : 1;
}
