#include <Python.h>
#include <float.h> /* for FLT_MAX */

#define UNSET_SCORE FLT_MAX

// Use a struct to make passing params during recursion easier.
typedef struct {
    const char  *haystack_p;        // Pointer to the path string to be searched.
    long        haystack_len;       // Length of same.
    const char  *needle_p;          // Pointer to search string (needle).
    long        needle_len;         // Length of same.
    long        *rightmost_match_p; // Rightmost match for each char in needle.
    float       max_score_per_char;
    int         case_sensitive;     // Boolean.
    float       *memo;              // Memoization.
} matchinfo_t;

float recursive_match(
    matchinfo_t *m,    // Sharable meta-data.
    long haystack_idx, // Where in the path string to start.
    long needle_idx,   // Where in the needle string to start.
    long last_idx,     // Location of last matched character.
    float score        // Cumulative score so far.
) {
    long distance, i, j;
    float *memoized = NULL;
    float score_for_char;
    float seen_score = 0;

    // Iterate over needle.
    for (i = needle_idx; i < m->needle_len; i++) {
        // Iterate over (valid range of) haystack.
        for (j = haystack_idx; j <= m->rightmost_match_p[i]; j++) {
            char c, d;

            // Do we have a memoized result we can return?
            memoized = &m->memo[j * m->needle_len + i];
            if (*memoized != UNSET_SCORE) {
                return *memoized > seen_score ? *memoized : seen_score;
            }
            c = m->needle_p[i];
            d = m->haystack_p[j];
            if (d >= 'A' && d <= 'Z' && !m->case_sensitive) {
                d += 'a' - 'A'; // Add 32 to downcase.
            }

            if (c == d) {
                // Calculate score.
                float sub_score = 0;
                score_for_char = m->max_score_per_char;
                distance = j - last_idx;

                if (distance > 1) {
                    float factor = 1.0;
                    char last = m->haystack_p[j - 1];
                    char curr = m->haystack_p[j]; // Case matters, so get again.
                    if (last == '/') {
                        factor = 0.9;
                    } else if (
                        last == '-' ||
                        last == '_' ||
                        last == ' ' ||
                        (last >= '0' && last <= '9')
                    ) {
                        factor = 0.8;
                    } else if (
                        last >= 'a' && last <= 'z' &&
                        curr >= 'A' && curr <= 'Z'
                    ) {
                        factor = 0.8;
                    } else if (last == '.') {
                        factor = 0.7;
                    } else {
                        // If no "special" chars behind char, factor diminishes
                        // as distance from last matched char increases.
                        factor = (1.0 / distance) * 0.75;
                    }
                    score_for_char *= factor;
                }

                if (j < m->rightmost_match_p[i]) {
                    sub_score = recursive_match(m, j + 1, i, last_idx, score);
                    if (sub_score > seen_score) {
                        seen_score = sub_score;
                    }
                }
                last_idx = j;
                haystack_idx = last_idx + 1;
                score += score_for_char;
                *memoized = seen_score > score ? seen_score : score;
                if (i == m->needle_len - 1) {
                    // Whole string matched.
                    return *memoized;
                }
            }
        }
    }
    return *memoized = score;
}

float calculate_match(
    const char *haystack,
    const char *needle,
    int case_sensitive
) {
    matchinfo_t m;
    long i;
    float score             = 1.0;
    m.haystack_p            = haystack;
    m.haystack_len          = strlen(haystack);
    m.needle_p              = needle;
    m.needle_len            = strlen(needle);
    m.rightmost_match_p     = NULL;
    m.max_score_per_char    = (1.0 / m.haystack_len + 1.0 / m.needle_len) / 2;
    m.case_sensitive        = case_sensitive;

    // Special case for zero-length search string.
    if (m.needle_len == 0) {
        return score;
    }

    long haystack_limit;
    long memo_size;
    long needle_idx;
    long mask;
    long rightmost_match_p[m.needle_len];

    // Pre-scan string:
    // - Bail if it can't match at all.
    // - Record rightmost match for each character (prune search space).
    m.rightmost_match_p = rightmost_match_p;
    needle_idx = m.needle_len - 1;
    mask = 0;
    for (i = m.haystack_len - 1; i >= 0; i--) {
        char c = m.haystack_p[i];
        char lower = c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
        if (!m.case_sensitive) {
            c = lower;
        }
        if (needle_idx >= 0) {
            char d = m.needle_p[needle_idx];
            if (c == d) {
                rightmost_match_p[needle_idx] = i;
                needle_idx--;
            }
        }
    }
    if (needle_idx != -1) {
        return 0.0;
    }

    // Prepare for memoization.
    haystack_limit = rightmost_match_p[m.needle_len - 1] + 1;
    memo_size = m.needle_len * haystack_limit;
    {
        float memo[memo_size];
        for (i = 0; i < memo_size; i++) {
            memo[i] = UNSET_SCORE;
        }
        m.memo = memo;
        score = recursive_match(&m, 0, 0, 0, 0.0);
    }
    return score;
}

static PyObject *score_calc(PyObject *self, PyObject *args) {
    const char *needle;
    const char *haystack;
    int case_sensitive;

    // See: https://docs.python.org/3/c-api/arg.html
    if (!PyArg_ParseTuple(args, "ssi", &needle, &haystack, &case_sensitive)) {
        return NULL;
    }

    return PyFloat_FromDouble(
        calculate_match(haystack, needle, case_sensitive)
    );
}

#define SENTINEL {NULL, NULL, 0, NULL}

static PyMethodDef module_methods[] = {
    {
        "calc",
        score_calc,
        METH_VARARGS,
        "Calculate a fuzzy match score for 'needle' in 'haystack'."
    },
    SENTINEL
};

// See: https://docs.python.org/3/c-api/module.html#initializing-modules
static struct PyModuleDef module_def = {
   PyModuleDef_HEAD_INIT,
   "score", // Module name.
   NULL, // Module docstring.
   -1, // No per-interpreter state.
   module_methods,
   NULL, // Single-phase initialization.
   NULL, // GC traversal function.
   NULL, // GC clearing function.
   NULL // Function to call when module is deallocated.
};

PyMODINIT_FUNC PyInit_score(void) {
    Py_Initialize();
    PyObject *m = PyModule_Create(&module_def);
    if (!m) {
        return NULL;
    }
    return m;
}
