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

static void find(str_t *dir, int fd, int depth, find_result_t *result) {
    if (depth < 0) {
        return;
    }

    DIR *stream = fdopendir(fd);

    if (stream == NULL) {
        result->error = strerror(errno);
        return;
    }

    struct dirent *entry;
    while (result->count < MAX_FILES && (entry = readdir(stream)) != NULL) {
        char *name = entry->d_name;
        if (
            strcmp(name, current_directory) == 0 ||
            strcmp(name, parent_directory) == 0
        ) {
            continue;
        } else if (entry->d_type == DT_DIR) {
            // Recurse.
            size_t previous_size = dir->length;
            str_append_char(dir, '/');
            str_append(dir, name, strlen(name));

            int dir_fd = openat(fd, name, O_DIRECTORY | O_RDONLY);
            if (dir_fd == -1) {
                result->error = strerror(errno);
                return;
            }

            find(dir, dir_fd, depth - 1, result);

            str_truncate(dir, previous_size);
            if (close(dir_fd) == -1) {
                result->error = strerror(errno);
                return;
            }
            if (result->error) {
                return;
            }
        } else if (entry->d_type == DT_LNK) {
            // Read link and recurse.
            char buf[PATH_MAX + 1];
            ssize_t siz = readlinkat(fd, name, buf, PATH_MAX);
            if (siz == -1) {
                result->error = strerror(errno);
                return;
            }
            buf[siz] = '\0';

            // Recurse if dir, otherwise loop...

            // TODO: finish this
        } else if (entry->d_type == DT_REG) {
            // Regular file.
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
    }
    if (closedir(stream) == -1) {
        result->error = strerror(errno);
    }
}

find_result_t *commandt_find(const char *dir) {
    find_result_t *result = xcalloc(1, sizeof(find_result_t));

    // TODO: once i am passing in max_files, don't bother asking for MAX_FILES
    result->files_size = sizeof(str_t) * MAX_FILES;
    result->files = xmap(result->files_size);

    result->buffer_size = buffer_size;
    result->buffer = xmap(result->buffer_size);

    // TODO: confirm this works if `dir` refers to a non-broken symlink (may
    // need to drop O_DIRECTORY)
    // TODO: see what happens if `dir` is a broken symlink
    int fd = open(dir, O_DIRECTORY | O_RDONLY);

    if (fd == -1) {
        result->error = strerror(errno);
    } else {
        str_t *str = str_new_size(PATH_MAX);
        str_append(str, dir, strlen(dir));
        // TODO: make this a param
        find(str, fd, MAX_DEPTH, result);
        str_free(str);

        if (close(fd) == -1) {
            result->error = strerror(errno);
        }
    }

    // TODO: copy result->error so it can be `free'd` by caller.
    return result;
}

void commandt_find_result_free(find_result_t *result) {
    assert(munmap(result->files, result->files_size) == 0);
    assert(munmap(result->buffer, result->buffer_size) == 0);
    free((void *)result->error);
    free(result);
}
