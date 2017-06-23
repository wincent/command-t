# Build, test, distribute with:
#
#       rm -r build dist              # Clean.
#       python3 setup.py build        # Build.
#       pip3 install --upgrade .      # Test locally.
#       python3 setup.py sdist        # Prepare source distribution.
#       python3 setup.py bdist_wheel  # Prepare binary distribution.
#       twine upload dist/*           # Distribute.
#
# For more info, see: https://docs.python.org/3/extending/building.html
from setuptools import setup, Extension

setup (name = 'commandt.score',
       version = '0.1.1',
       description = 'Command-T fuzzy match scoring algorithm',
       author = 'Greg Hurrell',
       author_email = 'greg@hurrell.net',
       url = 'https://github.com/wincent/command-t/tree/python/commandt/score',
       packages = ['commandt.score'],
       long_description = '''
This is the fuzzy match scoring algorithm, extracted from the Command-T (vim
plugin) project.
''',
       ext_package = 'commandt',
       ext_modules = [Extension('score', ['commandt/score/score.c'])],
       license = 'BSD',
       classifiers = [
           # From: https://pypi.python.org/pypi?%3Aaction=list_classifiers
           'Development Status :: 3 - Alpha',
           'Intended Audience :: Developers',
           'License :: OSI Approved :: BSD License',
           'Operating System :: MacOS :: MacOS X',
           'Operating System :: POSIX',
           'Programming Language :: C',
           'Programming Language :: Python :: 3 :: Only',
           ],
       )
