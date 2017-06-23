commandt.score
==============

This module exposes the Command-T fuzzy match scoring algorithm to Python as a C extension. The `calc` function returns a value between 0.0 and 1.0 indicating the quality of a fuzzy match (higher scores indicate better matches).

Usage:

::

  import commandt.score
  commandt.score.calc("needle", "score the needle in the haystack", 0)
