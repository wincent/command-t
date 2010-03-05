#include <ruby.h>

VALUE CommandTMatch_initialize(VALUE self, VALUE str, VALUE abbrev);
VALUE CommandTMatch_matches(VALUE self);
VALUE CommandTMatch_score(VALUE self);
VALUE CommandTMatch_to_s(VALUE self);
