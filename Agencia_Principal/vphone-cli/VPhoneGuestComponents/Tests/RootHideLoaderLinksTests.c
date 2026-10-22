#include "../Shared/RootHideLoaderLinks.h"
#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void directory(const char *path) { assert(mkdir(path, 0700) == 0); }
static void file(const char *path) {
    FILE *stream = fopen(path, "w");
    assert(stream);
    assert(fclose(stream) == 0);
}

// A thin arm64 image with one optional LC_RPATH and one LC_LOAD_DYLIB.
static void image(const char *path, const char *rpath, const char *dependency) {
    uint8_t commands[1024] = {0};
    uint32_t size = 0, count = 0;
    if (rpath) {
        struct rpath_command *command = (struct rpath_command *)(commands + size);
        uint32_t length = (uint32_t)((sizeof(*command) + strlen(rpath) + 8) & ~7ul);
        command->cmd = LC_RPATH;
        command->cmdsize = length;
        command->path.offset = sizeof(*command);
        strcpy((char *)command + sizeof(*command), rpath);
        size += length;
        count++;
    }
    struct dylib_command *command = (struct dylib_command *)(commands + size);
    uint32_t length = (uint32_t)((sizeof(*command) + strlen(dependency) + 8) & ~7ul);
    command->cmd = LC_LOAD_DYLIB;
    command->cmdsize = length;
    command->dylib.name.offset = sizeof(*command);
    strcpy((char *)command + sizeof(*command), dependency);
    size += length;
    count++;
    struct mach_header_64 header = {
        .magic = MH_MAGIC_64, .cputype = CPU_TYPE_ARM64, .filetype = MH_EXECUTE,
        .ncmds = count, .sizeofcmds = size,
    };
    FILE *stream = fopen(path, "w");
    assert(stream);
    assert(fwrite(&header, sizeof(header), 1, stream) == 1);
    assert(fwrite(commands, size, 1, stream) == 1);
    assert(fclose(stream) == 0);
}

static void expectLink(const char *directory, const char *target) {
    char path[PATH_MAX], text[PATH_MAX];
    assert((size_t)snprintf(path, sizeof(path), "%s/.jbroot", directory) < sizeof(path));
    ssize_t length = readlink(path, text, sizeof(text) - 1);
    assert(length > 0);
    text[length] = '\0';
    assert(strcmp(text, target) == 0);
    assert(unlink(path) == 0);
}

// sudo's shape: usr/bin/sudo has rpath @loader_path/.jbroot/usr/libexec/sudo
// and loads @rpath/libsudo_util.0.dylib, which loads a library elsewhere.
static void dependencies(const char *root) {
    const char *directories[] = {"usr", "usr/bin", "usr/lib", "usr/lib/deep", "usr/libexec", "usr/libexec/tool"};
    char path[PATH_MAX];
    for (size_t index = 0; index < sizeof(directories) / sizeof(*directories); index++) {
        assert((size_t)snprintf(path, sizeof(path), "%s/%s", root, directories[index]) < sizeof(path));
        directory(path);
    }
    char executable[PATH_MAX], library[PATH_MAX], deep[PATH_MAX];
    snprintf(executable, sizeof(executable), "%s/usr/bin/tool", root);
    snprintf(library, sizeof(library), "%s/usr/libexec/tool/libtool.0.dylib", root);
    snprintf(deep, sizeof(deep), "%s/usr/lib/deep/libdeep.dylib", root);
    image(executable, "@loader_path/.jbroot/usr/libexec/tool", "@rpath/libtool.0.dylib");
    image(library, NULL, "@loader_path/.jbroot/usr/lib/deep/libdeep.dylib");
    file(deep);

    assert(vpEnsureRootHideLoaderLink(executable, root) == 0);
    snprintf(path, sizeof(path), "%s/usr/bin", root);
    expectLink(path, "../..");
    snprintf(path, sizeof(path), "%s/usr/libexec/tool", root);
    expectLink(path, "../../..");
    snprintf(path, sizeof(path), "%s/usr/lib/deep", root);
    expectLink(path, "../../..");

    assert(unlink(executable) == 0);
    assert(unlink(library) == 0);
    assert(unlink(deep) == 0);
    for (size_t index = sizeof(directories) / sizeof(*directories); index > 0; index--) {
        assert((size_t)snprintf(path, sizeof(path), "%s/%s", root, directories[index - 1]) < sizeof(path));
        assert(rmdir(path) == 0);
    }
}

int main(void) {
    char scratch[] = "/tmp/vphone-loader-links.XXXXXX";
    assert(mkdtemp(scratch));
    char root[PATH_MAX], apps[PATH_MAX], bundle[PATH_MAX], executable[PATH_MAX], link[PATH_MAX];
    assert((size_t)snprintf(root, sizeof(root), "%s/.jbroot-000114514191980C", scratch) < sizeof(root));
    assert((size_t)snprintf(apps, sizeof(apps), "%s/Applications", root) < sizeof(apps));
    assert((size_t)snprintf(bundle, sizeof(bundle), "%s/TrollSpeed.app", apps) < sizeof(bundle));
    assert((size_t)snprintf(executable, sizeof(executable), "%s/TrollSpeed", bundle) < sizeof(executable));
    assert((size_t)snprintf(link, sizeof(link), "%s/.jbroot", bundle) < sizeof(link));
    directory(root);
    directory(apps);
    directory(bundle);
    file(executable);

    assert(vpEnsureRootHideLoaderLink(executable, root) == 0);
    char resolved[PATH_MAX], canonicalRoot[PATH_MAX], canonicalScratch[PATH_MAX];
    assert(realpath(root, canonicalRoot));
    assert(realpath(scratch, canonicalScratch));
    assert(realpath(link, resolved) && strcmp(resolved, canonicalRoot) == 0);
    assert(vpEnsureRootHideLoaderLink(executable, root) == 0);

    assert(unlink(link) == 0);
    assert(symlink(scratch, link) == 0);
    assert(vpEnsureRootHideLoaderLink(executable, root) == EEXIST);
    assert(realpath(link, resolved) && strcmp(resolved, canonicalScratch) == 0);

    assert(unlink(link) == 0);
    file(link);
    assert(vpEnsureRootHideLoaderLink(executable, root) == EEXIST);
    assert(unlink(link) == 0);

    char unrelated[PATH_MAX];
    assert((size_t)snprintf(unrelated, sizeof(unrelated), "%s/unrelated", scratch) < sizeof(unrelated));
    file(unrelated);
    assert(vpEnsureRootHideLoaderLink(unrelated, root) == 0);
    assert(unlink(unrelated) == 0);

    dependencies(root);

    assert(unlink(executable) == 0);
    assert(rmdir(bundle) == 0);
    assert(rmdir(apps) == 0);
    assert(rmdir(root) == 0);
    assert(rmdir(scratch) == 0);
    puts("RootHide loader link tests passed");
}
