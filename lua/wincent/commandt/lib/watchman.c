/**
 * SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h> /* for assert() */
#include <fcntl.h> /* for F_GETFL, F_SETFL, O_NONBLOCK, fcntl() */
#include <limits.h> /* for SSIZE_MAX */
#include <stdint.h> /* for uint8_t */
#include <stdlib.h> /* for free() */
#include <string.h> /* for memset(), strlen(), strcpy(), strncpy() */
#include <sys/errno.h> /* for errno */
#include <sys/mman.h> /* for munmap() */
#include <sys/socket.h> /* for AF_LOCAL, MSG_PEEK, MSG_WAITALL, recv() */
#include <sys/un.h> /* for sockaddr_un */
#include <unistd.h> /* for close() */

#include "debug.h"
#include "str.h"
#include "watchman.h"
#include "xmalloc.h" /* for xcalloc(), xmalloc(), xrealloc() */
#include "xmap.h" /* for xmap() */

typedef struct {
    uint8_t *payload;
    size_t capacity;
    size_t length;
} watchman_request_t;

// Forward declarations of static functions.

static void watchman_append(watchman_request_t *w, const char *data, size_t length);
static void watchman_append_char(watchman_request_t *w, char c);
static const char *watchman_error(const char *error);
static uint64_t watchman_read_array(watchman_response_t *r, const char **error);
static double watchman_read_double(watchman_response_t *r, const char **error);
static int64_t watchman_read_int(watchman_response_t *r, const char **error);
static uint64_t watchman_read_object(watchman_response_t *r, const char **error);
static str_t *watchman_read_string(watchman_response_t *r, const char **error);
static void watchman_read_string_no_copy(watchman_response_t *r, str_t *str, const char **error);
static void watchman_request_free(watchman_request_t *w);
static watchman_request_t *watchman_request_init();
static void watchman_response_free(watchman_response_t *r);
static watchman_response_t *watchman_send(watchman_request_t *w, int socket);
static void watchman_skip_value(watchman_response_t *r, const char **error);
static void watchman_write_array(watchman_request_t *w, unsigned length);
static void watchman_write_int(watchman_request_t *w, int64_t num);
static void watchman_write_object(watchman_request_t *w, unsigned size);
static void watchman_write_string(watchman_request_t *w, const char *string, size_t length);

#define WATCHMAN_DEFAULT_STORAGE    4096

#define WATCHMAN_BINARY_MARKER      "\x00\x01"
#define WATCHMAN_ARRAY_MARKER       0x00
#define WATCHMAN_OBJECT_MARKER      0x01
#define WATCHMAN_STRING_MARKER      0x02
#define WATCHMAN_INT8_MARKER        0x03
#define WATCHMAN_INT16_MARKER       0x04
#define WATCHMAN_INT32_MARKER       0x05
#define WATCHMAN_INT64_MARKER       0x06
#define WATCHMAN_DOUBLE_MARKER      0x07
#define WATCHMAN_TRUE               0x08
#define WATCHMAN_FALSE              0x09
#define WATCHMAN_NIL                0x0a
#define WATCHMAN_TEMPLATE_MARKER    0x0b
#define WATCHMAN_SKIP_MARKER        0x0c

#define WATCHMAN_HEADER \
        WATCHMAN_BINARY_MARKER \
        "\x06" \
        "\x00\x00\x00\x00\x00\x00\x00\x00"

// How far we have to look to figure out the size of the PDU header.
#define WATCHMAN_SNIFF_BUFFER_SIZE (sizeof(WATCHMAN_BINARY_MARKER) - 1 + sizeof(int8_t))

// How far we have to peek, at most, to figure out the size of the PDU itself.
#define WATCHMAN_PEEK_BUFFER_SIZE \
    (sizeof(WATCHMAN_BINARY_MARKER) - 1 + sizeof(typeof(WATCHMAN_INT64_MARKER)) + sizeof(int64_t))

int commandt_watchman_connect(const char *socket_path) {
    int fd = socket(PF_LOCAL, SOCK_STREAM, 0);
    if (fd == -1) {
        return -1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(struct sockaddr_un) - 1);
    addr.sun_family = AF_LOCAL;

    // On macOS, `sun_path` is 104 bytes long... so good thing the socket path
    // is only: "/opt/homebrew/var/run/watchman/$USER-state/sock"...
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(struct sockaddr_un)) == -1) {
        return -1;
    }

    // Do blocking I/O to make logic simpler.
    int flags = fcntl(fd, F_GETFL);
    if (flags == -1) {
        return -1;
    }
    if (fcntl(fd, F_SETFL, flags & ~O_NONBLOCK) == -1) {
        return -1;
    }

    return fd;
}

int commandt_watchman_disconnect(int socket) {
    if (close(socket) == 0) {
        return 0;
    } else {
        return errno;
    }
}

watchman_query_result_t *commandt_watchman_query(
    const char *root,
    const char *relative_root,
    int socket
) {
    // Prepare the message.
    //
    //     [
    //       "query",
    //       "/path/to/root", {
    //         "expression": ["type", "f"],
    //         "fields": ["name"],
    //         "relative_root": "relative/path"
    //       }
    //     ]
    //
    watchman_request_t *w = watchman_request_init();
    watchman_write_array(w, 3);
    watchman_write_string(w, "query", sizeof("query") - 1);
    watchman_write_string(w, root, strlen(root));
    watchman_write_object(w, relative_root ? 3 : 2);
    watchman_write_string(w, "expression", sizeof("expression") - 1);
    watchman_write_array(w, 2);
    watchman_write_string(w, "type", sizeof("type") - 1);
    watchman_write_string(w, "f", sizeof("f") - 1);
    watchman_write_string(w, "fields", sizeof("fields") - 1);
    watchman_write_array(w, 1);
    watchman_write_string(w, "name", sizeof("name") - 1);
    if (relative_root) {
        watchman_write_string(w, "relative_root", sizeof("relative_root") - 1);
        watchman_write_string(w, relative_root, strlen(relative_root));
    }
    watchman_response_t *r = watchman_send(w, socket);
    watchman_request_free(w);

    // Process the response:
    //
    watchman_query_result_t *result = xcalloc(1, sizeof(watchman_query_result_t));
    result->response = r;
    str_t *key = NULL;
    uint64_t count = watchman_read_object(r, &result->error);
    if (result->error) {
        goto done;
    }

    for (uint64_t i = 0; i < count; i++) {
        key = watchman_read_string(r, &result->error);
        if (result->error) {
            goto done;
        } else if (
            key->length == sizeof("files") - 1 &&
            strncmp(key->contents, "files", key->length) == 0
        ) {
            assert(!result->files);
            uint64_t file_count = watchman_read_array(r, &result->error);
            if (result->error) {
                goto done;
            }
            result->files_size = sizeof(str_t) * file_count;
            DEBUG_LOG("commandt_watchman_query() -> xmap() %llu\n", result->files_size);
            result->files = xmap(result->files_size);
            for (uint64_t j = 0; j < file_count; j++) {
                watchman_read_string_no_copy(r, &result->files[j], &result->error);
                if (result->error) {
                    goto done;
                }
            }
            result->count = file_count;
        } else if (
            key->length == sizeof("error") - 1 &&
            strncmp(key->contents, "error", key->length) == 0
        ) {
            str_t *error = watchman_read_string(r, &result->error);
            if (result->error) {
                goto done;
            } else {
                // Some song and dance here because string is not guaranteed to
                // be NUL-terminated.
                result->error = str_c_string(error);
                str_free(error);
                goto done_no_copy;
            }
        } else {
            // Skip over values we don't care about.
            watchman_skip_value(r, &result->error);
            if (result->error) {
                goto done;
            }
        }
        str_free(key);
        key = NULL;
    }
    if (!result->files) {
        result->error = "commandt_watchman_query(): no \"files\" value in \"query\" response";
        goto done;
    }
    assert(r->ptr == r->end);

done:
    if (result->error) {
        result->error = watchman_error(result->error); // Makes a copy.
    }
done_no_copy:
    if (key) {
        str_free(key);
    }
    return result;
}

watchman_watch_project_result_t *commandt_watchman_watch_project(
    const char *root,
    int socket
) {
#ifdef DEBUG
    DEBUG_LOG("watch-project %s\n", root);
#endif
    // Prepare and send the message:
    //
    //     ["watch-project", "/path/to/root"]
    //
    watchman_request_t *w = watchman_request_init();
    watchman_write_array(w, 2);
    watchman_write_string(w, "watch-project", sizeof("watch-project") - 1);
    watchman_write_string(w, root, strlen(root));
    watchman_response_t *r = watchman_send(w, socket);
    watchman_request_free(w);

    // Process the response:
    //
    //     {
    //       "watch": "/path/to/root",
    //       "relative_path": "optional/relative/path",
    //       "error": "If present, someting went wrong",
    //       ...
    //     }
    //
    watchman_watch_project_result_t *result =
        xcalloc(1, sizeof(watchman_watch_project_result_t));
    str_t *key = NULL;
    uint64_t count = watchman_read_object(r, &result->error);
    if (result->error) {
        goto done;
    }

    for (uint64_t i = 0; i < count; i++) {
        key = watchman_read_string(r, &result->error);
        if (result->error) {
            goto done;
        } else if (
            key->length == sizeof("watch") - 1 &&
            strncmp(key->contents, "watch", key->length) == 0
        ) {
            str_t *watch = watchman_read_string(r, &result->error);
            if (result->error) {
                goto done;
            }
            result->watch = watch->contents;
            free(watch);
        } else if (
            key->length == sizeof("relative_path") - 1 &&
            strncmp(key->contents, "relative_path", key->length) == 0
        ) {
            str_t *relative_path = watchman_read_string(r, &result->error);
            if (result->error) {
                goto done;
            }
            result->relative_path = relative_path->contents;
            free(relative_path);
        } else if (
            key->length == sizeof("error") - 1 &&
            strncmp(key->contents, "error", key->length) == 0
        ) {
            // Error may be something like:
            //
            //     std::system_error: open: : No such file or directory
            //
            // or:
            //
            //     watchman::RootResolveError: failed to resolve root:
            //     unable to resolve root $DIRECTORY: failed to parse json
            //     from $DIRECTORY/.watchmanconfig: '[' or '{' expected near
            //     end of file
            //
            str_t *error = watchman_read_string(r, &result->error);
            if (result->error) {
                goto done;
            } else {
                // Some song and dance here because string is not guaranteed to
                // be NUL-terminated.
                result->error = str_c_string(error);
                str_free(error);
                goto done_no_copy;
            }
        } else {
            // Skip over values we don't care about.
            watchman_skip_value(r, &result->error);
            if (result->error) {
                goto done;
            }
        }
        str_free(key);
        key = NULL;
    }
    if (!result->watch) {
        result->error = "commandt_watchman_watch_project(): no \"watch\" value in \"watch-project\" response";
        goto done;
    }
    assert(r->ptr == r->end);

done:
    if (result->error) {
        result->error = watchman_error(result->error); // Makes a copy.
    }
done_no_copy:
    watchman_response_free(r);
    if (key) {
        str_free(key);
    }

    return result;
}

void commandt_watchman_watch_project_result_free(
    watchman_watch_project_result_t *result
) {
    free((void *)result->watch);
    free((void *)result->relative_path);
    free((void *)result->error);
    free(result);
}

void commandt_watchman_query_result_free(watchman_query_result_t *result) {
    DEBUG_LOG("commandt_watchman_query_result_free() -> munmap() %llu\n", result->files_size);
    assert(munmap(result->files, result->files_size) == 0);
    free(result->response);
    free((void *)result->error);
    free(result);
}

/**
 * Appends `length` bytes, starting at `data`, to the watchman_request_t struct `w`
 *
 * Will attempt to reallocate the underlying storage if it is not sufficient.
 */
static void watchman_append(watchman_request_t *w, const char *data, size_t length) {
    if (w->length + length > w->capacity) {
        w->capacity += w->length + WATCHMAN_DEFAULT_STORAGE;
        xrealloc(w->payload, w->capacity);
    }
    memcpy(w->payload + w->length, data, length);
    w->length += length;
}

/**
 * Appends a single char, `c`, to the watchman_request_t struct `w`
 *
 * Will attempt to reallocate the underlying storage if it is not sufficient.
 */
static void watchman_append_char(watchman_request_t *w, char c) {
    if (w->length + 1 > w->capacity) {
        w->capacity += w->length + WATCHMAN_DEFAULT_STORAGE;
        xrealloc(w->payload, w->capacity);
    }
    w->payload[w->length++] = c;
}

/**
 * Makes and returns a copy of the supplied error string
 */
static const char *watchman_error(const char *error) {
    char *result = xmalloc(strlen(error) + 1);
    strcpy(result, error);
    return result;
}

/**
 * Returns count of values in the array.
 */
static uint64_t watchman_read_array(watchman_response_t *r, const char **error) {
    assert(error != NULL);
    int64_t count = 0;
    if (r->ptr >= r->end) {
        *error = "watchman_read_array(): unexpected end of input";
        goto done;
    }

    // Verify and consume marker.
    if (r->ptr[0] == WATCHMAN_ARRAY_MARKER) {
        r->ptr++;
        if (r->ptr + 2 > r->end) {
            *error = "watchman_read_array(): incomplete array header";
            goto done;
        }
        count = watchman_read_int(r, error);
        if (*error) {
            goto done;
        }
    } else {
        *error = "watchman_read_array(): not an array";
        goto done;
    }
    if (count < 0) {
        *error = "watchman_read_array(): negative count";
        goto done;
    }
done:
    return count;
}

/**
 * Reads and returns a double encoded in the Watchman binary protocol format,
 * starting at `ptr` and finishing at or before `end`
 */
static double watchman_read_double(watchman_response_t *r, const char **error) {
    assert(error != NULL);
    double val = 0.0;

    if (r->ptr + sizeof(typeof(WATCHMAN_DOUBLE_MARKER)) + sizeof(double) > r->end) {
        *error = "watchman_read_double(): insufficient double storage";
        goto done;
    }

    // Verify and consume marker.
    if (r->ptr[0] == WATCHMAN_DOUBLE_MARKER) {
        r->ptr += sizeof(typeof(WATCHMAN_DOUBLE_MARKER));
        val = *(double *)r->ptr;
        r->ptr += sizeof(double);
    } else {
        *error = "watchman_read_double(): not an object";
        goto done;
    }
done:
    return val;
}

static int64_t watchman_read_int(watchman_response_t *r, const char **error) {
    assert(error != NULL);
    char *val_ptr = r->ptr + sizeof(int8_t);
    int64_t val = 0;

    if (val_ptr >= r->end) {
        *error = "watchman_read_int(): insufficient int storage";
        goto done;
    }

    switch (r->ptr[0]) {
        case WATCHMAN_INT8_MARKER:
            if (val_ptr + sizeof(int8_t) > r->end) {
                *error = "watchman_read_int(): overrun extracting int8_t";
                goto done;
            }
            val = *(int8_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int8_t);
            break;
        case WATCHMAN_INT16_MARKER:
            if (val_ptr + sizeof(int16_t) > r->end) {
                *error = "watchman_read_int(): overrun extracting int16_t";
                goto done;
            }
            val = *(int16_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int16_t);
            break;
        case WATCHMAN_INT32_MARKER:
            if (val_ptr + sizeof(int32_t) > r->end) {
                *error = "watchman_read_int(): overrun extracting int32_t";
                goto done;
            }
            val = *(int32_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int32_t);
            break;
        case WATCHMAN_INT64_MARKER:
            if (val_ptr + sizeof(int64_t) > r->end) {
                *error = "watchman_read_int(): overrun extracting int64_t";
                goto done;
            }
            val = *(int64_t *)val_ptr;
            r->ptr = val_ptr + sizeof(int64_t);
            break;
        default:
            *error = "watchman_read_int(): bad integer marker";
            break;
    }

done:
    return val;
}

/**
 * Returns count of key/value pairs in the object.
 */
static uint64_t watchman_read_object(watchman_response_t *r, const char **error) {
    assert(error != NULL);
    int64_t count = 0;
    if (r->ptr >= r->end) {
        *error = "watchman_read_object(): unexpected end of input";
        goto done;
    }

    // Verify and consume marker.
    if (r->ptr[0] == WATCHMAN_OBJECT_MARKER) {
        r->ptr++;
        if (r->ptr + 2 > r->end) {
            *error = "watchman_read_object(): incomplete hash header";
            goto done;
        }
        count = watchman_read_int(r, error);
        if (*error) {
            goto done;
        }
    } else {
        *error = "watchman_read_object(): not an object";
        goto done;
    }
    if (count < 0) {
        *error = "watchman_read_object(): negative count";
    }
done:
    return count;
}

/**
 * Reads and returns a string encoded in the Watchman binary protocol format,
 * starting at `r->ptr` and finishing at or before `r->end`
 */
static str_t *watchman_read_string(watchman_response_t *r, const char **error) {
    assert(error != NULL);
    if (r->ptr >= r->end) {
        *error = "watchman_read_string(): unexpected end of input";
        return NULL;
    }

    if (r->ptr[0] != WATCHMAN_STRING_MARKER) {
        *error = "watchman_read_string(): not a string";
        return NULL;
    }

    r->ptr += sizeof(int8_t);
    if (r->ptr >= r->end) {
        *error = "watchman_read_string(): invalid string header";
        return NULL;
    }

    int64_t length = watchman_read_int(r, error);
    if (*error) {
        return NULL;
    }
    if (length == 0) { // Special case for zero-length strings.
        return str_new_copy("", 0);
    } else if (r->ptr + length > r->end) {
        *error = "watchman_read_string(): insufficient string storage";
        return NULL;
    }

    str_t *string = str_new_copy(r->ptr, length);
    r->ptr += length;
    return string;
}

/**
 * Reads and returns a string encoded in the Watchman binary protocol format,
 * starting at `r->ptr` and finishing at or before `r->end` into the `str_t`
 * struct indicated by `str`.
 *
 * Note that unlike `watchman_read_string()`, this function does not create a
 * copy of the bytes but rather uses a pointer directly into the response's
 * payload buffer, as a performance optimization. The downstream consumer of
 * this information (typically, the caller of `commandt_watchman_query()`)
 * will be responsible for freeing the payload all at once via a call to
 * `commandt_watchman_query_result_free()`.
 *
 * The strings will _not_ be NUL-terminated, so callers should be careful not to
 * assume that any `str_t` `contents` field points at a NUL-terminated string.
 */
static void watchman_read_string_no_copy(watchman_response_t *r, str_t *str, const char **error) {
    assert(error != NULL);
    if (r->ptr >= r->end) {
        *error = "watchman_read_string_no_copy(): unexpected end of input";
        return;
    }

    if (r->ptr[0] != WATCHMAN_STRING_MARKER) {
        *error = "watchman_read_string_no_copy(): not a string";
        return;
    }

    r->ptr += sizeof(int8_t);
    if (r->ptr >= r->end) {
        *error = "watchman_read_string_no_copy(): invalid string header";
        return;
    }

    int64_t length = watchman_read_int(r, error);
    if (*error) {
        return;
    }
    if (r->ptr + length > r->end) {
        *error = "watchman_read_string_no_copy(): insufficient string storage";
        return;
    }

    str_init(str, r->ptr, length);
    r->ptr += length;
}

/**
 * Free a watchman_request_t struct `w` that was previously allocated with
 * `watchman_request_init`
 */
static void watchman_request_free(watchman_request_t *w) {
    free(w->payload);
    free(w);
}

/**
 * Allocate a new watchman_request_t struct
 *
 * The struct has a small amount of extra capacity preallocated, and a blank
 * header that can be filled in later to describe the PDU.
 */
static watchman_request_t *watchman_request_init() {
    watchman_request_t *w = xmalloc(sizeof(watchman_request_t));
    w->capacity = WATCHMAN_DEFAULT_STORAGE;
    w->length = 0;
    w->payload = xcalloc(WATCHMAN_DEFAULT_STORAGE, sizeof(uint8_t));
    watchman_append(w, WATCHMAN_HEADER, sizeof(WATCHMAN_HEADER) - 1);
    return w;
}

static void watchman_response_free(watchman_response_t *r) {
    free(r->payload);
    free(r);
}

static watchman_response_t *watchman_send(watchman_request_t *w, int socket) {
    watchman_response_t *r = xmalloc(sizeof(watchman_response_t));
    r->capacity = WATCHMAN_DEFAULT_STORAGE;
    r->payload = xmalloc(WATCHMAN_DEFAULT_STORAGE);
    r->ptr = r->payload;
    r->end = r->payload;

    // Send the message.
    assert(w->length < SSIZE_MAX);
    ssize_t length = w->length;
    ssize_t sent = send(socket, w->payload, w->length, 0);
    if (sent == -1 || sent != length) {
        return NULL; // TODO: don't leak response for these early returns
    }

    // Sniff to see how large the header is.
    ssize_t received = recv(socket, r->payload, WATCHMAN_SNIFF_BUFFER_SIZE, MSG_PEEK | MSG_WAITALL);
    if (received == -1 || received != WATCHMAN_SNIFF_BUFFER_SIZE) {
        return NULL;
    }

    // Peek at size of PDU.
    int8_t sizes_idx = r->ptr[sizeof(WATCHMAN_BINARY_MARKER) - 1];
    if (sizes_idx < WATCHMAN_INT8_MARKER || sizes_idx > WATCHMAN_INT64_MARKER) {
        return NULL;
    }
    int8_t sizes[] = {0, 0, 0, 1, 2, 4, 8};
    ssize_t peek_size = sizeof(WATCHMAN_BINARY_MARKER) - 1 + sizeof(int8_t) +
        sizes[sizes_idx];

    received = recv(socket, r->payload, peek_size, MSG_PEEK);
    if (received == -1 || received != peek_size) {
        return NULL;
    }
    r->ptr = r->ptr + sizeof(WATCHMAN_BINARY_MARKER) - sizeof(int8_t);
    r->end = r->ptr + peek_size;
    const char *error = NULL;
    int64_t payload_size = peek_size + watchman_read_int(r, &error);
    if (error) {
        return NULL;
    }

    // Actually read the PDU.
    assert(payload_size > 0);
    if ((size_t)payload_size > r->capacity) {
        r->payload = xrealloc(r->payload, payload_size);
    }

    received = recv(socket, r->payload, payload_size, MSG_WAITALL);
    if (received == -1 || received != payload_size) {
        return NULL;
    }

    r->ptr = r->payload + peek_size;
    r->end = r->payload + payload_size;
    r->capacity = payload_size;

    return r;
}

static void watchman_skip_value(watchman_response_t *r, const char **error) {
    assert(error != NULL);
    if (r->ptr >= r->end) {
        *error = "watchman_skip_value(): unexpected end of input";
        return;
    }

    switch (r->ptr[0]) {
        case WATCHMAN_ARRAY_MARKER:
            {
                uint64_t count = watchman_read_array(r, error);
                if (*error) {
                    return;
                }
                for (uint64_t i = 0; i < count; i++) {
                    watchman_skip_value(r, error);
                }
            }
            break;
        case WATCHMAN_OBJECT_MARKER:
            {
                uint64_t count = watchman_read_object(r, error);
                if (*error) {
                    return;
                }
                for (uint64_t i = 0; i < count; i++) {
                    watchman_skip_value(r, error); // Skip key.
                    watchman_skip_value(r, error); // Skip value.
                }
            }
            break;
        case WATCHMAN_STRING_MARKER:
            (void)watchman_read_string(r, error);
            if (*error) {
                return;
            }
            break;
        case WATCHMAN_INT8_MARKER:
        case WATCHMAN_INT16_MARKER:
        case WATCHMAN_INT32_MARKER:
        case WATCHMAN_INT64_MARKER:
            (void)watchman_read_int(r, error);
            if (*error) {
                return;
            }
            break;
        case WATCHMAN_DOUBLE_MARKER:
            (void)watchman_read_double(r, error);
            if (*error) {
                return;
            }
            break;
        case WATCHMAN_TRUE:
        case WATCHMAN_FALSE:
        case WATCHMAN_NIL:
        case WATCHMAN_SKIP_MARKER: // Should only appear in templates.
            r->ptr++;
            break;
        case WATCHMAN_TEMPLATE_MARKER:
            {
                // Skip: marker, array of key names, array of value tuples.
                // See: https://github.com/facebook/watchman/blob/main/website/_docs/BSER.markdown
                r->ptr++;
                uint64_t key_count = watchman_read_array(r, error);
                if (*error) {
                    return;
                }
                for (uint64_t i = 0; i < key_count; i++) {
                    watchman_skip_value(r, error);
                    if (*error) {
                        return;
                    }
                }
                uint64_t object_count = watchman_read_array(r, error);
                if (*error) {
                    return;
                }
                for (uint64_t i = 0; i < object_count; i++) {
                    for (uint64_t j = 0; j < key_count; j++) {
                        watchman_skip_value(r, error);
                        if (*error) {
                            return;
                        }
                    }
                }
            }
            break;
        default:
            *error = "watchman_skip_value(): unsupported type";
    }
}

static void watchman_write_array(watchman_request_t *w, unsigned length) {
    watchman_append_char(w, WATCHMAN_ARRAY_MARKER);
    watchman_write_int(w, length);
}

/**
 * Encodes and appends the integer `num` to `w`
 */
static void watchman_write_int(watchman_request_t *w, int64_t num) {
    char encoded[1 + sizeof(int64_t)];
    if (num == (int8_t)num) {
        encoded[0] = WATCHMAN_INT8_MARKER;
        encoded[1] = (int8_t)num;
        watchman_append(w, encoded, 1 + sizeof(int8_t));
    } else if (num == (int16_t)num) {
        encoded[0] = WATCHMAN_INT16_MARKER;
        *(int16_t *)(encoded + 1) = (int16_t)num;
        watchman_append(w, encoded, 1 + sizeof(int16_t));
    } else if (num == (int32_t)num) {
        encoded[0] = WATCHMAN_INT32_MARKER;
        *(int32_t *)(encoded + 1) = (int32_t)num;
        watchman_append(w, encoded, 1 + sizeof(int32_t));
    } else {
        encoded[0] = WATCHMAN_INT64_MARKER;
        *(int64_t *)(encoded + 1) = (int64_t)num;
        watchman_append(w, encoded, 1 + sizeof(int64_t));
    }
}

/**
 * Prepares to encode an object of `size` key/value pairs.
 *
 * After calling this, the caller should call, for each key/value pair, first
 * `watchman_write_string()` (for the key), then some other `watchman_write`
 * function for the value.
 */
static void watchman_write_object(watchman_request_t *w, unsigned size) {
    watchman_append_char(w, WATCHMAN_OBJECT_MARKER);
    watchman_write_int(w, size);
}

/**
 * Encodes and appends the string `string` to `w`
 */
static void watchman_write_string(watchman_request_t *w, const char *string, size_t length) {
    watchman_append_char(w, WATCHMAN_STRING_MARKER);
    watchman_write_int(w, length);
    watchman_append(w, string, length);
}
