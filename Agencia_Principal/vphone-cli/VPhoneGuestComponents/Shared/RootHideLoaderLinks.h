#ifndef VPHONE_ROOT_HIDE_LOADER_LINKS_H
#define VPHONE_ROOT_HIDE_LOADER_LINKS_H

// Ensure @loader_path/.jbroot can resolve before dyld starts the child: in the
// executable's directory, in each @loader_path/.jbroot rpath directory, and
// in the directory of each dependency dyld will find inside the bootstrap,
// walked through its own load commands within a fixed bound.
// Returns zero on success or when no change is needed, otherwise the first errno.
int vpEnsureRootHideLoaderLink(const char *executable, const char *root);

#endif
