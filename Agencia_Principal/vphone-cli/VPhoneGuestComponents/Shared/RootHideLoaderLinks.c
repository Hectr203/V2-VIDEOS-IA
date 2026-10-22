#include "RootHideLoaderLinks.h"
#include <errno.h>
#include <fcntl.h>
#include <libkern/OSByteOrder.h>
#include <limits.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// The walk runs in PID 1 before every bootstrap spawn, so it reads at most
// this many images, remembers this many rpaths and reads this much of each
// image's load commands.
#define VP_MAX_IMAGES 32
#define VP_MAX_RPATHS 16
#define VP_MAX_COMMANDS (512 * 1024)

static const char vpLoaderPrefix[] = "@loader_path/.jbroot/";
static const char vpRPathPrefix[] = "@rpath/";

typedef struct {
    char root[PATH_MAX];
    char images[VP_MAX_IMAGES][PATH_MAX];
    size_t imageCount;
    char rpaths[VP_MAX_RPATHS][PATH_MAX];
    size_t rpathCount;
    int status;
} VPLinkWalk;

static int vpWithin(const char *path, const char *directory) {
    size_t length = strlen(directory);
    return strncmp(path, directory, length) == 0 &&
           (path[length] == '/' || path[length] == '\0');
}

static int vpLinkTarget(const char *directory, const char *root, char target[PATH_MAX]) {
    const char *relative = directory + strlen(root);
    if (!*relative) {
        strcpy(target, ".");
        return 0;
    }
    size_t depth = 0;
    for (const char *cursor = relative; *cursor; cursor++) {
        if (*cursor == '/')
            depth++;
    }
    if (depth * 3 >= PATH_MAX)
        return ENAMETOOLONG;
    target[0] = '\0';
    for (size_t index = 0; index < depth; index++)
        strcat(target, index ? "/.." : "..");
    return 0;
}

// `directory` and `root` are canonical, and `directory` is inside `root`.
static int vpEnsureDirectoryLink(const char *directory, const char *root) {
    char target[PATH_MAX];
    int status = vpLinkTarget(directory, root, target);
    if (status)
        return status;
    int descriptor = open(directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0)
        return errno;
    struct stat info;
    if (fstatat(descriptor, ".jbroot", &info, AT_SYMLINK_NOFOLLOW) == 0) {
        if (!S_ISLNK(info.st_mode)) {
            close(descriptor);
            return EEXIST;
        }
        char linkPath[PATH_MAX];
        char resolved[PATH_MAX];
        int used = snprintf(linkPath, sizeof(linkPath), "%s/.jbroot", directory);
        status = used <= 0 || (size_t)used >= sizeof(linkPath) ? ENAMETOOLONG :
                 !realpath(linkPath, resolved) ? errno :
                 strcmp(resolved, root) == 0 ? 0 : EEXIST;
    } else if (errno == ENOENT) {
        status = symlinkat(target, descriptor, ".jbroot") == 0 ? 0 : errno;
    } else {
        status = errno;
    }
    close(descriptor);
    return status;
}

static void vpNote(VPLinkWalk *walk, int status) {
    if (status && !walk->status)
        walk->status = status;
}

// Reads the arm64 slice's load commands. Returns NULL for anything else.
static uint8_t *vpReadCommands(const char *path, uint32_t *count, uint32_t *size) {
    int descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0)
        return NULL;
    uint8_t *commands = NULL;
    off_t offset = 0;
    uint32_t magic = 0;
    if (pread(descriptor, &magic, sizeof(magic), 0) != sizeof(magic))
        goto done;
    if (magic == FAT_CIGAM) {
        struct fat_header fat;
        if (pread(descriptor, &fat, sizeof(fat), 0) != sizeof(fat))
            goto done;
        uint32_t slices = OSSwapBigToHostInt32(fat.nfat_arch);
        int found = 0;
        for (uint32_t index = 0; index < slices && index < 16 && !found; index++) {
            struct fat_arch arch;
            off_t at = (off_t)sizeof(fat) + (off_t)index * (off_t)sizeof(arch);
            if (pread(descriptor, &arch, sizeof(arch), at) != sizeof(arch))
                goto done;
            if ((cpu_type_t)OSSwapBigToHostInt32((uint32_t)arch.cputype) == CPU_TYPE_ARM64) {
                offset = OSSwapBigToHostInt32(arch.offset);
                found = 1;
            }
        }
        if (!found)
            goto done;
    }
    struct mach_header_64 header;
    if (pread(descriptor, &header, sizeof(header), offset) != sizeof(header) ||
        header.magic != MH_MAGIC_64 || header.cputype != CPU_TYPE_ARM64 ||
        header.sizeofcmds == 0 || header.sizeofcmds > VP_MAX_COMMANDS)
        goto done;
    commands = malloc(header.sizeofcmds);
    if (!commands)
        goto done;
    if (pread(descriptor, commands, header.sizeofcmds, offset + (off_t)sizeof(header)) !=
        (ssize_t)header.sizeofcmds) {
        free(commands);
        commands = NULL;
        goto done;
    }
    *count = header.ncmds;
    *size = header.sizeofcmds;
done:
    close(descriptor);
    return commands;
}

// The string a load command stores at `offset`, if it ends inside the command.
static const char *vpCommandString(const struct load_command *command, uint32_t offset) {
    if (offset < sizeof(*command) || offset >= command->cmdsize)
        return NULL;
    const char *string = (const char *)command + offset;
    size_t room = command->cmdsize - offset;
    return strnlen(string, room) < room ? string : NULL;
}

// Maps @loader_path/.jbroot/x to <root>/x. Everything else is outside the
// bootstrap or already covered by the loading image's own directory.
static int vpBootstrapPath(const VPLinkWalk *walk, const char *name, char path[PATH_MAX]) {
    if (strncmp(name, vpLoaderPrefix, sizeof(vpLoaderPrefix) - 1) != 0)
        return 0;
    const char *relative = name + sizeof(vpLoaderPrefix) - 2;
    int used = snprintf(path, PATH_MAX, "%s%s", walk->root, relative);
    return used > 0 && used < PATH_MAX;
}

static void vpVisitImage(VPLinkWalk *walk, const char *image);

// Links the directory holding `candidate` and walks it, when it is a file
// inside the bootstrap. Returns whether it exists.
static int vpVisitDependency(VPLinkWalk *walk, const char *candidate) {
    char canonical[PATH_MAX];
    struct stat info;
    if (!realpath(candidate, canonical) || stat(canonical, &info) != 0 || !S_ISREG(info.st_mode))
        return 0;
    if (!vpWithin(canonical, walk->root))
        return 1;
    vpVisitImage(walk, canonical);
    return 1;
}

static void vpAddRPath(VPLinkWalk *walk, const char *name) {
    char path[PATH_MAX];
    char canonical[PATH_MAX];
    if (!vpBootstrapPath(walk, name, path) || !realpath(path, canonical) ||
        !vpWithin(canonical, walk->root))
        return;
    for (size_t index = 0; index < walk->rpathCount; index++) {
        if (strcmp(walk->rpaths[index], canonical) == 0)
            return;
    }
    // A plugin a library dlopens from its rpath directory needs the link too.
    vpNote(walk, vpEnsureDirectoryLink(canonical, walk->root));
    if (walk->rpathCount < VP_MAX_RPATHS)
        strcpy(walk->rpaths[walk->rpathCount++], canonical);
}

// `image` is canonical and inside the root. Its directory gets a link, then
// each dependency dyld will look for inside the bootstrap is visited.
static void vpVisitImage(VPLinkWalk *walk, const char *image) {
    for (size_t index = 0; index < walk->imageCount; index++) {
        if (strcmp(walk->images[index], image) == 0)
            return;
    }
    if (walk->imageCount >= VP_MAX_IMAGES)
        return;
    strcpy(walk->images[walk->imageCount++], image);

    char directory[PATH_MAX];
    strcpy(directory, image);
    char *leaf = strrchr(directory, '/');
    if (!leaf || leaf == directory)
        return;
    *leaf = '\0';
    vpNote(walk, vpEnsureDirectoryLink(directory, walk->root));

    uint32_t count = 0;
    uint32_t size = 0;
    uint8_t *commands = vpReadCommands(image, &count, &size);
    if (!commands)
        return;
    // dyld searches the rpaths of every image on the loading chain, so they
    // are all collected before any @rpath dependency is looked up.
    for (int pass = 0; pass < 2; pass++) {
        uint32_t offset = 0;
        for (uint32_t index = 0; index < count && offset + sizeof(struct load_command) <= size; index++) {
            const struct load_command *command = (const struct load_command *)(commands + offset);
            if (command->cmdsize < sizeof(*command) || command->cmdsize > size - offset)
                break;
            offset += command->cmdsize;
            if (pass == 0) {
                if (command->cmd == LC_RPATH && command->cmdsize >= sizeof(struct rpath_command)) {
                    const char *name = vpCommandString(command, ((const struct rpath_command *)command)->path.offset);
                    if (name)
                        vpAddRPath(walk, name);
                }
                continue;
            }
            if (command->cmd != LC_LOAD_DYLIB && command->cmd != LC_LOAD_WEAK_DYLIB &&
                command->cmd != LC_REEXPORT_DYLIB && command->cmd != LC_LAZY_LOAD_DYLIB &&
                command->cmd != LC_LOAD_UPWARD_DYLIB)
                continue;
            if (command->cmdsize < sizeof(struct dylib_command))
                continue;
            const char *name = vpCommandString(command, ((const struct dylib_command *)command)->dylib.name.offset);
            if (!name)
                continue;
            char candidate[PATH_MAX];
            if (vpBootstrapPath(walk, name, candidate)) {
                vpVisitDependency(walk, candidate);
            } else if (strncmp(name, vpRPathPrefix, sizeof(vpRPathPrefix) - 1) == 0) {
                const char *leafName = name + sizeof(vpRPathPrefix) - 1;
                for (size_t rpath = 0; rpath < walk->rpathCount; rpath++) {
                    int used = snprintf(candidate, sizeof(candidate), "%s/%s", walk->rpaths[rpath], leafName);
                    if (used > 0 && (size_t)used < sizeof(candidate) && vpVisitDependency(walk, candidate))
                        break;
                }
            }
        }
    }
    free(commands);
}

int vpEnsureRootHideLoaderLink(const char *executable, const char *root) {
    if (!executable || !root || !strstr(root, "/.jbroot-"))
        return 0;
    const char *namedRoot = root;
    if (strncmp(root, "/private/var/", 13) == 0 && strncmp(executable, "/var/", 5) == 0)
        namedRoot += 8;
    if (!vpWithin(executable, namedRoot))
        return 0;

    VPLinkWalk *walk = calloc(1, sizeof(*walk));
    if (!walk)
        return ENOMEM;
    char canonicalExecutable[PATH_MAX];
    int status = 0;
    if (!realpath(root, walk->root) || !realpath(executable, canonicalExecutable)) {
        status = errno;
    } else if (vpWithin(canonicalExecutable, walk->root)) {
        char *leaf = strrchr(canonicalExecutable, '/');
        if (!leaf || leaf == canonicalExecutable) {
            status = EINVAL;
        } else {
            vpVisitImage(walk, canonicalExecutable);
            status = walk->status;
        }
    }
    free(walk);
    return status;
}
