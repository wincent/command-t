/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

// TODO: implement max_depth, max_files
// TODO: follow symlinks (ie. `find -L`)
// TODO: implement scan_dot_directories
// TODO: check what `find` does for symlink cycles; it detects and aborts

#include <assert.h> /* for assert() */
#include <dirent.h> /* for DT_DIR, DT_LNK, DT_REG, closedir(), opendir(), readdir() */
#include <errno.h> /* for errno */
#include <fcntl.h> /* for O_DIRECTORY, O_RDONLY */
#include <limits.h> /* for PATH_MAX */
#include <stdlib.h> /* for free() */
#include <string.h> /* for strerror() */
#include <sys/mman.h> /* for munmap() */
#include <sys/stat.h> /* for fstatat() */
#include <sys/types.h> /* for DIR */
#include <unistd.h> /* for close(), readlink() */

#include "find.h"
#include "xmalloc.h"
#include "xmap.h"

// TODO: share these with scanner.c
static long MAX_FILES = 134217728; // 128 M candiates.
static size_t buffer_size = 137438953472; // 128 GB.

#define MAX_DEPTH 64

static const char *current_directory = ".";
static const char *parent_directory = "..";

// Forward declarations.
static void visit_directory(str_t *dir, int fd, char *name, int depth, find_result_t *result);
static void visit_file(str_t *dir, char *name, find_result_t *result);
static void visit_link(str_t *dir, int fd, char *name, int depth, find_result_t *result);

// TODO: make this visit(), and teach it to visit anything at all
// which means if it is a file, return it
// if it is a link, traverse it (recurse)
// if it is a dir, recurse

// TODO: may want to model this as a queue and do iteration instead of recursion
static void visit_directory(str_t *dir, int fd, char *name, int depth, find_result_t *result) {
    if (depth < 0) {
        return;
    }

    // TODO: confirm this works if `name` refers to a non-broken symlink (may need to drop O_DIRECTORY)
    // TODO: see what happens if `name` is a broken symlink
    size_t previous_size = dir->length;
    if (fd == -1){
        fd = open(name, O_DIRECTORY | O_RDONLY);
    } else {
        fd = openat(fd, name, O_DIRECTORY | O_RDONLY);
        str_append_char(dir, '/');
    }
    str_append(dir, name, strlen(name));

    if (fd == -1) {
        result->error = strerror(errno);
        goto done;
    }

    DIR *stream = fdopendir(fd);

    if (stream == NULL) {
        result->error = strerror(errno);
        goto done;
    }

    struct dirent *entry;
    while (
            result->count < MAX_FILES &&
            !result->error &&
            (entry = readdir(stream)) != NULL
    ) {
        if (
            strcmp(entry->d_name, current_directory) == 0 ||
            strcmp(entry->d_name, parent_directory) == 0
        ) {
            continue;
        } else if (entry->d_type == DT_DIR) {
            visit_directory(dir, fd, entry->d_name, depth - 1, result);
        } else if (entry->d_type == DT_LNK) {
            visit_link(dir, fd, entry->d_name, depth - 1, result);
        } else if (entry->d_type == DT_REG) {
            visit_file(dir, entry->d_name, result);
        }
    }
    if (closedir(stream) == -1) {
        result->error = strerror(errno);
    }

done:
    str_truncate(dir, previous_size);
    if (fd != -1 && close(fd) == -1) {
        result->error = strerror(errno);
    }
}

static void visit_file(str_t *dir, char *name, find_result_t *result) {
    char *dest = result->count
        ? (char *)result->files[result->count - 1].contents
        : result->buffer;
    size_t length = strlen(name);
    str_t file = result->files[result->count];
    str_init(&file, dest, dir->length + 1 + length);
    dest = memcpy(dest, dir->contents, dir->length) + dir->length;
    dest[dir->length] = '/';
    memcpy(dest + 1, name, length);
    result->count++;
}

static void visit_link(str_t *dir, int fd, char *name, int depth, find_result_t *result) {
    // BUG: note that all of this is probably super racy...
    if (depth < 0) {
        return;
    }

    struct stat buf;
    if (fstatat(fd, name, &buf, 0) == -1) {
        // TODO: may just want to silently skip here
        result->error = strerror(errno);
        return;
    }
    if (S_ISREG(buf.st_mode)) {
        visit_file(dir, name, result);
    } else if (S_ISDIR(buf.st_mode)) {
        visit_directory(dir, fd, name, depth - 1, result);
    } else if (S_ISLNK(buf.st_mode)) {
        // TODO: readlink
        ssize_t bufsize = PATH_MAX * 2;
        char buf[bufsize];
        ssize_t size = readlinkat(fd, name, buf, bufsize);
        if (size == -1) {
            result->error = strerror(errno);
        } else if (size == bufsize) {
            // Truncation may have occurred. Give up, like a coward.
        } else {
            visit_link(dir, fd, buf, depth - 1, result);
        }
    }
}

find_result_t *commandt_find(const char *dir) {
    find_result_t *result = xcalloc(1, sizeof(find_result_t));

    // TODO: once i am passing in max_files, don't bother asking for MAX_FILES
    result->files_size = sizeof(str_t) * MAX_FILES;
    result->files = xmap(result->files_size);

    result->buffer_size = buffer_size;
    result->buffer = xmap(result->buffer_size);

    // Start with PATH_MAX (which, infamously, may not be big enough);
    // we'll grow it if need be.
    str_t *str = str_new_size(PATH_MAX);
    // TODO: make MAX_DEPTH a param
    visit_directory(str, -1, (char *)dir, MAX_DEPTH, result);
    str_free(str);

    // TODO: copy result->error so it can be `free'd` by caller.
    return result;
}

void commandt_find_result_free(find_result_t *result) {
    assert(munmap(result->files, result->files_size) == 0);
    assert(munmap(result->buffer, result->buffer_size) == 0);
    free((void *)result->error);
    free(result);
}
