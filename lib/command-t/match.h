#include <ruby.h>

extern VALUE CommandTMatch_initialize(VALUE self, VALUE str, VALUE abbrev);
extern VALUE CommandTMatch_matches(VALUE self);
extern VALUE CommandTMatch_score(VALUE self);
extern VALUE CommandTMatch_to_s(VALUE self);
