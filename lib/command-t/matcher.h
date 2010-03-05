#include <ruby.h>

extern VALUE CommandTMatcher_initialize(VALUE self, VALUE scanner);
extern VALUE CommandTMatcher_sorted_matchers_for(VALUE self, VALUE abbrev, VALUE options);

// most likely the function will be subsumed by the sorted_matcher_for function
extern VALUE CommandTMatcher_matches_for(VALUE self, VALUE abbrev);
