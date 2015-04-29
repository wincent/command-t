*command-t.txt* Command-T plug-in for Vim         *command-t*

CONTENTS                                        *command-t-contents*

 1. Introduction            |command-t-intro|
 2. Requirements            |command-t-requirements|
 3. Installation            |command-t-installation|
 4. Trouble-shooting        |command-t-trouble-shooting|
 5. Usage                   |command-t-usage|
 6. Commands                |command-t-commands|
 7. Mappings                |command-t-mappings|
 8. Options                 |command-t-options|
 9. FAQ                     |command-t-faq|
10. Tips                    |command-t-tips|
11. Authors                 |command-t-authors|
12. Development             |command-t-development|
13. Website                 |command-t-website|
14. License                 |command-t-license|
15. History                 |command-t-history|


INTRODUCTION                                    *command-t-intro*

The Command-T plug-in provides an extremely fast, intuitive mechanism for
opening files and buffers with a minimal number of keystrokes. It's named
"Command-T" because it is inspired by the "Go to File" window bound to
Command-T in TextMate.

Files are selected by typing characters that appear in their paths, and are
ordered by an algorithm which knows that characters that appear in certain
locations (for example, immediately after a path separator) should be given
more weight.

To search efficiently, especially in large projects, you should adopt a
"path-centric" rather than a "filename-centric" mentality. That is you should
think more about where the desired file is found rather than what it is
called. This means narrowing your search down by including some characters
from the upper path components rather than just entering characters from the
filename itself.

Screencasts demonstrating the plug-in can be viewed at:

  https://wincent.com/products/command-t


REQUIREMENTS                                    *command-t-requirements*

The plug-in requires Vim compiled with Ruby support, a compatible Ruby
installation at the operating system level, and a C compiler to build
the Ruby extension.


1. Vim compiled with Ruby support ~

You can check for Ruby support by launching Vim with the --version switch:

  vim --version

If "+ruby" appears in the version information then your version of Vim has
Ruby support.

Another way to check is to simply try using the :ruby command from within Vim
itself:

  :ruby 1

If your Vim lacks support you'll see an error message like this:

  E319: Sorry, the command is not available in this version

The version of Vim distributed with OS X may not include Ruby support (for
example, Snow Leopard, which was the current version of OS X when Command-T
was first released, did not support Ruby in the system Vim, but the current
version of OS X at the time of writing, Mavericks, does). All recent versions
of MacVim come with Ruby support; it is available from:

  http://github.com/b4winckler/macvim/downloads

For Windows users, the Vim 7.2 executable available from www.vim.org does
include Ruby support, and is recommended over version 7.3 (which links against
Ruby 1.9, but apparently has some bugs that need to be resolved).


2. Ruby ~

In addition to having Ruby support in Vim, your system itself must have a
compatible Ruby install. "Compatible" means the same version as Vim itself
links against. If you use a different version then Command-T is unlikely
to work (see |command-t-trouble-shooting| below).

On OS X Snow Leopard, Lion and Mountain Lion, the system comes with Ruby 1.8.7
and all recent versions of MacVim (the 7.2 snapshots and 7.3) are linked
against it.

On OS X Mavericks, the default system Ruby is 2.0, but MacVim continues to
link against 1.8.7, as does the Apple-provided Vim. Ruby 1.8.7 is present on
the system at:

  /System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby

On OS X Yosemite, the default system Ruby is 2.0, and the Vim that comes with
the system links against it.

On Linux and similar platforms, the linked version of Ruby will depend on
your distribution. You can usually find this out by examining the
compilation and linking flags displayed by the |:version| command in Vim, and
by looking at the output of:

  :ruby puts "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"

Or, for very old versions of Ruby which don't define `RUBY_PATCHLEVEL`:

  :ruby puts RUBY_VERSION

Some Linux distributions package Ruby development tools separately from Ruby
itself; if you're using such a system you may need to install the "ruby-dev",
"ruby-devel" or similar package using your system's package manager in order
to build Command-T.

A suitable Ruby environment for Windows can be installed using the Ruby
1.8.7-p299 RubyInstaller available at:

  http://rubyinstaller.org/downloads/archives

If using RubyInstaller be sure to download the installer executable, not the
7-zip archive. When installing mark the checkbox "Add Ruby executables to your
PATH" so that Vim can find them.


3. C compiler ~

Part of Command-T is implemented in C as a Ruby extension for speed, allowing
it to work responsively even on directory hierarchies containing enormous
numbers of files. As such, a C compiler is required in order to build the
extension and complete the installation.

On OS X, this can be obtained by installing the Xcode Tools from the App
Store.

On Windows, the RubyInstaller Development Kit can be used to conveniently
install the necessary tool chain:

  http://rubyinstaller.org/downloads/archives

At the time of writing, the appropriate development kit for use with Ruby
1.8.7 is DevKit-3.4.5r3-20091110.

To use the Development Kit extract the archive contents to your C:\Ruby
folder.


INSTALLATION                                    *command-t-installation*

You install Command-T by obtaining the source files and building the C
extension.

The recommended way to get the source is by using a plug-in management system.
There are several such systems available, and my preferred one is Pathogen
(https://github.com/tpope/vim-pathogen) due to its simplicity and robustness.

Other plug-in managers include:

- Vundle: https://github.com/gmarik/Vundle.vim (see |command-t-vundle|)
- NeoBundle: https://github.com/Shougo/neobundle.vim (see
  |command-t-neobundle|)
- VAM: https://github.com/MarcWeber/vim-addon-manager (see |command-t-vam|)

The following sections outline how to use each of these managers to download
Command-T, and finally |command-t-compile| describes how to compile it.

                                                         *command-t-pathogen*
Obtaining the source using Pathogen ~

Pathogen is a plugin that allows you to maintain plugin installations in
separate, isolated subdirectories under the "bundle" directory in your
|'runtimepath'|. The following examples assume that you already have
Pathogen installed and configured, and that you are installing into
`~/.vim/bundle`.

If you manage your entire `~/.vim` folder using Git then you can add the
Command-T repository as a submodule:

  cd ~/.vim
  git submodule add git://git.wincent.com/command-t.git bundle/command-t
  git submodule init

Or if you just wish to do a simple clone instead of using submodules:

  cd ~/.vim
  git clone git://git.wincent.com/command-t.git bundle/command-t

Once you have a local copy of the repository you can update it at any time
with:

  cd ~/.vim/bundle/command-t
  git pull

Or you can switch to a specific release with:

  cd ~/.vim/bundle/command-t
  git checkout 1.10

To generate the help tags under Pathogen it is necessary to do so explicitly
from inside Vim:

  :call pathogen#helptags()

For more information about Pathogen, see:

  https://github.com/tpope/vim-pathogen

                                                           *command-t-vundle*
Obtaining the source using Vundle ~

Anywhere between the calls to `vundle#begin` and `vundle#end` in your
`~/.vimrc`, add a `Plugin` directive telling Vundle of your desire to use
Command-T:

  call vundle#begin()
  Plugin 'wincent/command-t'
  call vundle#end()

To actually install the plug-in run `:PluginInstall` from inside Vim. After
this, you can proceed to compile Command-T (see |command-t-compile|).

For more information about Vundle, see:

  https://github.com/gmarik/Vundle.vim

                                                        *command-t-neobundle*
Obtaining the source using NeoBundle ~

Anywhere between the calls to `neobundle#begin` and `neobundle#end` in your
`~/.vimrc`, add a `NeoBundle` directive telling NeoBundle of your desire to use
Command-T:

  call neobundle#begin(expand('~/.vim/bundle/'))
  NeoBundle 'wincent/command-t'
  call neobundle#end()

To actually install the plug-in run `:NeoBundleInstall` from inside Vim. After
this, you can proceed to compile Command-T (see |command-t-compile|).

For more information about NeoBundle, see:

  https://github.com/Shougo/neobundle.vim
                                                              *command-t-vam*
Obtaining the source using VAM ~

After the call to `vam#ActivateAddons` in your `~/.vimrc`, add Command-T to
the `VAMActivate` call:

  call vam#ActivateAddons([])
  VAMActivate github:wincent/command-t

After VAM has downloaded Command-T, you can proceed to compile it (see
|command-t-compile|).

For more information about VAM, see:

  https://github.com/MarcWeber/vim-addon-manager

                                                         *command-t-compile*
Compiling Command-T ~

The C extension must be built, which can be done from the shell. If you use a
typical Pathogen, Vundle or NeoBundle set-up then the files were installed inside
`~/.vim/bundle/command-t`. A typical VAM installation path might be
`~/.vim/vim-addons/command-t`.

Wherever the Command-T files were installed, you can build the extension by
changing to the `ruby/command-t` subdirectory and running a couple of commands
as follows:

  cd ~/.vim/bundle/command-t/ruby/command-t
  ruby extconf.rb
  make

Note: If you are an RVM or rbenv user, you must build CommandT using the same
version of Ruby that Vim itself is linked against. You can find out the
version that Vim is linked against by issuing following command inside Vim:

  :ruby puts "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"

Or, for very old versions of Ruby which don't define `RUBY_PATCHLEVEL`:

  :ruby puts RUBY_VERSION

You can either set your version of Ruby to the output of the above command and
then build Command-T, or re-build Vim with a version of Ruby you prefer.

To set the version of Ruby, issue one of the following commands before
the `make` command:

  rvm use VERSION # where "VERSION" is the Ruby version Vim is linked against
  rbenv local VERSION

If you decide to re-build Vim, for OS X, you can simply use Homebrew to
uninstall and re-install Vim with following commands:

  brew uninstall vim
  brew install vim

For more information about Homebrew, see:

  http://brew.sh

Note: If you are on OS X Mavericks and compiling against MacVim, the default
system Ruby is 2.0 but MacVim still links against the older 1.8.7 Ruby that is
also bundled with the system; in this case the build command becomes:

  cd ~/.vim/bundle/command-t/ruby/command-t
  /System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby extconf.rb
  make

Note: Make sure you compile targeting the same architecture Vim was built for.
For instance, MacVim binaries are built for i386, but sometimes GCC compiles
for x86_64. First you have to check the platform Vim was built for:

  vim --version
  ...
  Compilation: gcc ... -arch i386 ...
  ...

and make sure you use the correct ARCHFLAGS during compilation:

  export ARCHFLAGS="-arch i386"
  make

Note: If you are on Fedora 17+, you can install Command-T from the system
repository with:

  su -c 'yum install vim-command-t'

                                                       *command-t-appstream*
AppStream Metadata ~

When preparing a Command-T package for distribution on Linux using Gnome
Software or another AppStream compatible application, there is a metafile in
appstream directory.

You can find more about AppStream specification at:

  http://www.freedesktop.org/software/appstream/docs/


TROUBLE-SHOOTING                                *command-t-trouble-shooting*

Most installation problems are caused by a mismatch between the version of
Ruby on the host operating system, and the version of Ruby that Vim itself
linked against at compile time. For example, if one is 32-bit and the other is
64-bit, or one is from the Ruby 1.9 series and the other is from the 1.8
series, then the plug-in is not likely to work.

On OS X, Apple tends to change the version of Ruby that comes with the system
with each major release. See |command-t-requirements| above for details about
specific versions. If you wish to use custom builds of Ruby or of MacVim then
you will have to take extra care to ensure that the exact same Ruby
environment is in effect when building Ruby, Vim and the Command-T extension.

For Windows, the following combination is known to work:

  - Vim 7.2 from http://www.vim.org/download.php:
      ftp://ftp.vim.org/pub/vim/pc/gvim72.exe
  - Ruby 1.8.7-p299 from http://rubyinstaller.org/downloads/archives:
      http://rubyforge.org/frs/download.php/71492/rubyinstaller-1.8.7-p299.exe
  - DevKit 3.4.5r3-20091110 from http://rubyinstaller.org/downloads/archives:
      http://rubyforge.org/frs/download.php/66888/devkit-3.4.5r3-20091110.7z

If a problem occurs the first thing you should do is inspect the output of:

  ruby extconf.rb
  make

During the installation, and:

  vim --version

And compare the compilation and linker flags that were passed to the
extension and to Vim itself when they were built. If the Ruby-related
flags or architecture flags are different then it is likely that something
has changed in your Ruby environment and the extension may not work until
you eliminate the discrepancy.

From inside Vim, you can confirm the version of Ruby that it is using by
issuing this command:

  :ruby puts "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}"

Or, for very old versions of Ruby which don't define `RUBY_PATCHLEVEL`:

  :ruby puts RUBY_VERSION

Additionally, beware that if you change your installation method for Command-T
(for example, switching from one plugin manager to another) you should verify
that you remove all of the files installed by the previous installation
method; if you fail to do this, Vim may end up executing the old code,
invalidating all your attempts to get Vim and Command-T using the same version
of Ruby.

Finally, if you end up changing Ruby versions or upgrading other parts of the
system (the operating system itself, or Vim, for example), you may need to
issue an additional "make clean" before re-building Command-T; this ensures
that potentially incompatible build products are disposed of and re-created
during the build:

  make clean
  ruby extconf.rb
  make


USAGE                                           *command-t-usage*

Bring up the Command-T file window by typing:

  <Leader>t

This mapping is set up automatically for you, provided you do not already have
a mapping for <Leader>t or |:CommandT|. You can also bring up the file window
by issuing the command:

  :CommandT

A prompt will appear at the bottom of the screen along with a file window
showing all of the files in the current project (the project directory is
determined according to the value of the |g:CommandTTraverseSCM| setting,
which defaults to the SCM root of the current file).

You can pass in an optional path argument to |:CommandT| (relative to the
current working directory (|:pwd|) or absolute):

  :CommandT ../path/to/other/files

Type letters in the prompt to narrow down the selection, showing only the
files whose paths contain those letters in the specified order. Letters do not
need to appear consecutively in a path in order for it to be classified as a
match.

Once the desired file has been selected it can be opened by pressing <CR>.
(By default files are opened in the current window, but there are other
mappings that you can use to open in a vertical or horizontal split, or in
a new tab.) Note that if you have |'nohidden'| set and there are unsaved
changes in the current window when you press <CR> then opening in the current
window would fail; in this case Command-T will open the file in a new split.

The following mappings are active when the prompt has focus:

    <BS>        delete the character to the left of the cursor
    <Del>       delete the character at the cursor
    <Left>      move the cursor one character to the left
    <C-h>       move the cursor one character to the left
    <Right>     move the cursor one character to the right
    <C-l>       move the cursor one character to the right
    <C-a>       move the cursor to the start (left)
    <C-e>       move the cursor to the end (right)
    <C-u>       clear the contents of the prompt
    <Tab>       change focus to the file listing

The following mappings are active when the file listing has focus:

    <Tab>       change focus to the prompt

The following mappings are active when either the prompt or the file listing
has focus:

    <CR>        open the selected file
    <C-CR>      open the selected file in a new split window
    <C-s>       open the selected file in a new split window
    <C-v>       open the selected file in a new vertical split window
    <C-t>       open the selected file in a new tab
    <C-j>       select next file in the file listing
    <C-n>       select next file in the file listing
    <Down>      select next file in the file listing
    <C-k>       select previous file in the file listing
    <C-p>       select previous file in the file listing
    <Up>        select previous file in the file listing
    <C-f>       flush the cache (see |:CommandTFlush| for details)
    <C-q>       place the current matches in the quickfix window
    <C-c>       cancel (dismisses file listing)

The following is also available on terminals which support it:

    <Esc>       cancel (dismisses file listing)

Note that the default mappings can be overriden by setting options in your
`~/.vimrc` file (see the OPTIONS section for a full list of available options).

In addition, when the file listing has focus, typing a character will cause
the selection to jump to the first path which begins with that character.
Typing multiple characters consecutively can be used to distinguish between
paths which begin with the same prefix.


COMMANDS                                        *command-t-commands*

                                                *:CommandT*
|:CommandT|       Brings up the Command-T file window, starting in the
                current working directory as returned by the|:pwd|
                command.

                                                *:CommandTBuffer*
|:CommandTBuffer| Brings up the Command-T buffer window.
                This works exactly like the standard file window,
                except that the selection is limited to files that
                you already have open in buffers.

                                                *:CommandTMRU*
|:CommandTMRU|    Brings up the Command-T buffer window, except that matches
                are shown in MRU (most recently used) order. If you prefer to
                use this over the normal buffer finder, I suggest overwriting
                the standard mapping with a command like:

                    :nnoremap <silent> <leader>b :CommandTMRU<CR>

                Note that Command-T only starts recording most recently used
                buffers when you first use a Command-T command or mapping;
                this is an optimization to improve startup time.

                                                *:CommandTJumps*
|:CommandTJump|   Brings up the Command-T jumplist window.
                This works exactly like the standard file window,
                except that the selection is limited to files that
                you already have in the jumplist. Note that jumps
                can persist across Vim sessions (see Vim's |jumplist|
                documentation for more info).

                                                *:CommandTTag*
|:CommandTTag|    Brings up the Command-T window tags window, which can
                be used to select from the tags, if any, returned by
                Vim's |taglist()| function. See Vim's |tag| documentation
                for general info on tags.

                                                *:CommandTFlush*
|:CommandTFlush|  Instructs the plug-in to flush its path cache, causing
                the directory to be rescanned for new or deleted paths
                the next time the file window is shown (pressing <C-f> when
                a match listing is visible flushes the cache immediately; this
                mapping is configurable via the |g:CommandTRefreshMap|
                setting). In addition, all configuration settings are
                re-evaluated, causing any changes made to settings via the
                |:let| command to be picked up.

                                                *:CommandTLoad*
|:CommandTLoad|   Immediately loads the plug-in files, if they haven't been
                loaded already (normally, the files are loaded lazily the
                first time you run a Command-T command or use a Command-T
                mapping). This command may be useful for people wishing to
                extend Command-T by "monkey patching" its functionality.


MAPPINGS                                        *command-t-mappings*

By default Command-T comes with only two mappings:

  <Leader>t     bring up the Command-T file window
  <Leader>b     bring up the Command-T buffer window

However, Command-T won't overwrite a pre-existing mapping so if you prefer
to define different mappings use lines like these in your `~/.vimrc`:

  nnoremap <silent> <Leader>t :CommandT<CR>
  nnoremap <silent> <Leader>b :CommandTBuffer<CR>

Replacing "<Leader>t" or "<Leader>b" with your mapping of choice.

Note that in the case of MacVim you actually can map to Command-T (written
as <D-t> in Vim) in your `~/.gvimrc` file if you first unmap the existing menu
binding of Command-T to "New Tab":

  if has("gui_macvim")
    macmenu &File.New\ Tab key=<nop>
    map <D-t> :CommandT<CR>
  endif

When the Command-T window is active a number of other additional mappings
become available for doing things like moving between and selecting matches.
These are fully described above in the USAGE section, and settings for
overriding the mappings are listed below under OPTIONS.


OPTIONS                                         *command-t-options*

A number of options may be set in your `~/.vimrc` to influence the behaviour of
the plug-in. To set an option, you include a line like this in your `~/.vimrc`:

    let g:CommandTMaxFiles=20000

To have Command-T pick up new settings immediately (that is, without having
to restart Vim) you can issue the |:CommandTFlush| command after making
changes via |:let|.

Following is a list of all available options:

                                               *g:CommandTMaxFiles*
  |g:CommandTMaxFiles|                           number (default 30000)

      The maximum number of files that will be considered when scanning the
      current directory. Upon reaching this number scanning stops. This
      limit applies only to file listings and is ignored for buffer
      listings.

                                               *g:CommandTMaxDepth*
  |g:CommandTMaxDepth|                           number (default 15)

      The maximum depth (levels of recursion) to be explored when scanning the
      current directory. Any directories at levels beyond this depth will be
      skipped.

                                               *g:CommandTMaxCachedDirectories*
  |g:CommandTMaxCachedDirectories|               number (default 1)

      The maximum number of directories whose contents should be cached when
      recursively scanning. With the default value of 1, each time you change
      directories the cache will be emptied and Command-T will have to
      rescan. Higher values will make Command-T hold more directories in the
      cache, bringing performance at the cost of memory usage. If set to 0,
      there is no limit on the number of cached directories.

                                               *g:CommandTMaxHeight*
  |g:CommandTMaxHeight|                          number (default: 0)

      The maximum height in lines the match window is allowed to expand to.
      If set to 0, the window will occupy as much of the available space as
      needed to show matching entries.

                                               *g:CommandTInputDebounce*
  |g:CommandTInputDebounce|                      number (default: 50)

      The number of milliseconds to wait before updating the match listing
      following a key-press. This can be used to avoid wasteful recomputation
      when making a rapid series of key-presses in a directory with many tens
      (or hundreds) of thousands of files.

                                               *g:CommandTFileScanner*
  |g:CommandTFileScanner|                        string (default: 'ruby')

      The underlying scanner implementation that should be used to explore the
      filesystem. Possible values are:

      - "ruby": uses built-in Ruby and should work everywhere, albeit slowly
        on large (many tens of thousands of files) hierarchies.

      - "find": uses the command-line tool of the same name, which can be much
        faster on large projects because it is written in pure C, but may not
        work on systems without the tool or with an incompatible version of
        the tool.

      - "git": uses `git ls-files` to quickly produce a list of files; when
        Git isn't available or the path being searched is not inside a Git
        repository falls back to "find".

      - "watchman": uses Watchman (https://github.com/facebook/watchman) if
        available; otherwise falls back to "find". Note that this scanner is
        intended for use with very large hierarchies (hundreds of thousands of
        files) and so the task of deciding which files should be included is
        entirely delegated to Watchman; this means that settings which
        Command-T would usually consult, such as 'wildignore' and
        |g:CommandTScanDotDirectories| are ignored.

                                               *g:CommandTTraverseSCM*
  |g:CommandTTraverseSCM|                        string (default: 'file')

      Instructs Command-T how to choose a root path when opening a file finder
      without an explicit path argument. Possible values are:

      - "file": starting from the file currently being edited, traverse
        upwards through the filesystem hierarchy until you find an SCM root
        (as indicated by the presence of a ".git", ".hg" or similar directory)
        and use that as the base path. If no such root is found, fall back to
        using Vim's present working directory as a root. The list of SCM
        directories that Command-T uses to detect an SCM root can be
        customized with the |g:CommandTSCMDirectories| option.

      - "dir": traverse upwards looking for an SCM root just like the "file"
        setting (above), but instead of starting from the file currently being
        edited, start from Vim's present working directory instead.

      - "pwd": use Vim's present working directory as a root (ie. attempt no
        traversal).

                                               *g:CommandTGitScanSubmodules*
  |g:CommandTGitScanSubmodules|                  boolean (default: 0)

      If set to 1, Command-T will scan submodules (recursively) when using the
      "git" file scanner (see |g:CommandTFileScanner|).


                                               *g:CommandTSCMDirectories*
  |g:CommandTSCMDirectories|    string (default: '.git,.hg,.svn,.bzr,_darcs')

      The marker directories that Command-T will use to identify SCM roots
      during traversal (see |g:CommandTTraverseSCM| above).


                                               *g:CommandTMinHeight*
  |g:CommandTMinHeight|                          number (default: 0)

      The minimum height in lines the match window is allowed to shrink to.
      If set to 0, will default to a single line. If set above the max height,
      will default to |g:CommandTMaxHeight|.

                                               *g:CommandTAlwaysShowDotFiles*
  |g:CommandTAlwaysShowDotFiles|                 boolean (default: 0)

      When showing the file listing Command-T will by default show dot-files
      only if the entered search string contains a dot that could cause a
      dot-file to match. When set to a non-zero value, this setting instructs
      Command-T to always include matching dot-files in the match list
      regardless of whether the search string contains a dot. See also
      |g:CommandTNeverShowDotFiles|. Note that this setting only influences
      the file listing; the buffer listing treats dot-files like any other
      file.

                                               *g:CommandTNeverShowDotFiles*
  |g:CommandTNeverShowDotFiles|                  boolean (default: 0)

      In the file listing, Command-T will by default show dot-files if the
      entered search string contains a dot that could cause a dot-file to
      match. When set to a non-zero value, this setting instructs Command-T to
      never show dot-files under any circumstances. Note that it is
      contradictory to set both this setting and
      |g:CommandTAlwaysShowDotFiles| to true, and if you do so Vim will suffer
      from headaches, nervous twitches, and sudden mood swings. This setting
      has no effect in buffer listings, where dot files are treated like any
      other file.

                                               *g:CommandTScanDotDirectories*
  |g:CommandTScanDotDirectories|                 boolean (default: 0)

      Normally Command-T will not recurse into "dot-directories" (directories
      whose names begin with a dot) while performing its initial scan. Set
      this setting to a non-zero value to override this behavior and recurse.
      Note that this setting is completely independent of the
      |g:CommandTAlwaysShowDotFiles| and |g:CommandTNeverShowDotFiles|
      settings; those apply only to the selection and display of matches
      (after scanning has been performed), whereas
      |g:CommandTScanDotDirectories| affects the behaviour at scan-time.

      Note also that even with this setting off you can still use Command-T to
      open files inside a "dot-directory" such as `~/.vim`, but you have to use
      the |:cd| command to change into that directory first. For example:

        :cd ~/.vim
        :CommandT

                                               *g:CommandTMatchWindowAtTop*
  |g:CommandTMatchWindowAtTop|                   boolean (default: 0)

      When this setting is off (the default) the match window will appear at
      the bottom so as to keep it near to the prompt. Turning it on causes the
      match window to appear at the top instead. This may be preferable if you
      want the best match (usually the first one) to appear in a fixed location
      on the screen rather than moving as the number of matches changes during
      typing.

                                                *g:CommandTMatchWindowReverse*
  |g:CommandTMatchWindowReverse|                  boolean (default: 0)

      When this setting is off (the default) the matches will appear from
      top to bottom with the topmost being selected. Turning it on causes the
      matches to be reversed so the best match is at the bottom and the
      initially selected match is the bottom most. This may be preferable if
      you want the best match to appear in a fixed location on the screen
      but still be near the prompt at the bottom.

                                                *g:CommandTTagIncludeFilenames*
  |g:CommandTTagIncludeFilenames|                 boolean (default: 0)

      When this setting is off (the default) the matches in the |:CommandTTag|
      listing do not include filenames.

                                                *g:CommandTHighlightColor*
  |g:CommandTHighlightColor|                      string (default: 'PmenuSel')

      Specifies the highlight color that will be used to show the currently
      selected item in the match listing window.

                                                *g:CommandTWildIgnore*
  |g:CommandTWildIgnore|                          string (default: none)

      Optionally override Vim's global |'wildignore'| setting during Command-T
      searches. If you wish to supplement rather than replace the global
      setting, you can use a syntax like:

        let g:CommandTWildIgnore=&wildignore . ",**/bower_components/*"

      See also |command-t-wildignore|.

                                                *g:CommandTIgnoreCase*
  |g:CommandTIgnoreCase|                          boolean (default: 1)

      Ignore case when searching. Defaults to on, which means that searching
      is case-insensitive by default. See also |g:CommandTSmartCase|.

                                                *g:CommandTSmartCase*
  |g:CommandTSmartCase|                           boolean (default: none)

      Override the |g:CommandTIgnoreCase| setting if the search pattern
      contains uppercase characters, forcing the match to be case-sensitive.
      If unset (which is the default), the value of the Vim |'smartcase'|
      setting will be used instead.

                                              *g:CommandTAcceptSelectionCommand*
  |g:CommandTAcceptSelectionCommand|            string (default: 'e')

      The Vim command that will be used to open a selection from the match
      listing (via |g:CommandTAcceptSelectionMap|).

      For an example of how this can be used to apply arbitrarily complex
      logic, see the example in |g:CommandTAcceptSelectionTabCommand| below.

                                           *g:CommandTAcceptSelectionTabCommand*
  |g:CommandTAcceptSelectionTabCommand|      string (default: 'tabe')

      The Vim command that will be used to open a selection from the match
      listing in a new tab (via |g:CommandTAcceptSelectionSplitMap|).

      For example, this can be used to switch to an existing buffer (rather
      than opening a duplicate buffer with the selection in a new tab) with
      configuration such as the following:

          set switchbuf=usetab

          function! GotoOrOpen(...)
            for file in a:000
              if bufwinnr(file) != -1
                exec "sb " . file
              else
                exec "tabe " . file
              endif
            endfor
          endfunction

          command! -nargs=+ GotoOrOpen call GotoOrOpen("<args>")

          let g:CommandTAcceptSelectionTabCommand = 'GotoOrOpen'

      For a slightly more comprehensive example, see: https://wt.pe/e

                                        *g:CommandTAcceptSelectionSplitCommand*
  |g:CommandTAcceptSelectionSplitCommand| string (default: 'sp')

      The Vim command that will be used to open a selection from the match
      listing in a split (via |g:CommandTAcceptSelectionVSplitMap|).

      For an example of how this can be used to apply arbitrarily complex
      logic, see the example in |g:CommandTAcceptSelectionTabCommand| above.

                                        *g:CommandTAcceptSelectionVsplitCommand*
                                        string (default: 'vs')
  |g:CommandTAcceptSelectionVSplitCommand|

      The Vim command that will be used to open a selection from the match
      listing in a vertical split (via |g:CommandTAcceptSelectionVSplitMap|).

      For an example of how this can be used to apply arbitrarily complex
      logic, see the example in |g:CommandTAcceptSelectionTabCommand| above.

                                              *g:CommandTEncoding*
  |g:CommandTEncoding|                          string (default: none)

      In most environments Command-T will work just fine using the character
      encoding settings from your local environment. This setting can be used
      to force Command-T to use a specific encoding, such as "UTF-8", if your
      environment ends up defaulting to an undesired encoding, such as
      "ASCII-8BIT".

As well as the basic options listed above, there are a number of settings that
can be used to override the default key mappings used by Command-T. For
example, to set <C-x> as the mapping for cancelling (dismissing) the Command-T
window, you would add the following to your `~/.vimrc`:

  let g:CommandTCancelMap='<C-x>'

Multiple, alternative mappings may be specified using list syntax:

  let g:CommandTCancelMap=['<C-x>', '<C-c>']

Following is a list of all map settings and their defaults:

                              Setting   Default mapping(s)

                                      *g:CommandTBackspaceMap*
              |g:CommandTBackspaceMap|  <BS>

                                      *g:CommandTDeleteMap*
                 |g:CommandTDeleteMap|  <Del>

                                      *g:CommandTAcceptSelectionMap*
        |g:CommandTAcceptSelectionMap|  <CR>

                                      *g:CommandTAcceptSelectionSplitMap*
   |g:CommandTAcceptSelectionSplitMap|  <C-CR>
                                      <C-s>

                                      *g:CommandTAcceptSelectionTabMap*
     |g:CommandTAcceptSelectionTabMap|  <C-t>

                                      *g:CommandTAcceptSelectionVSplitMap*
  |g:CommandTAcceptSelectionVSplitMap|  <C-v>

                                      *g:CommandTToggleFocusMap*
            |g:CommandTToggleFocusMap|  <Tab>

                                      *g:CommandTCancelMap*
                 |g:CommandTCancelMap|  <C-c>
                                      <Esc> (not on all terminals)

                                      *g:CommandTSelectNextMap*
             |g:CommandTSelectNextMap|  <C-n>
                                      <C-j>
                                      <Down>

                                      *g:CommandTSelectPrevMap*
             |g:CommandTSelectPrevMap|  <C-p>
                                      <C-k>
                                      <Up>

                                      *g:CommandTClearMap*
                  |g:CommandTClearMap|  <C-u>

                                      *g:CommandTClearPrevWordMap*
          |g:CommandTClearPrevWordMap|  <C-w>

                                      *g:CommandTRefreshMap*
                |g:CommandTRefreshMap|  <C-f>

                                      *g:CommandTQuickfixMap*
               |g:CommandTQuickfixMap|  <C-q>

                                      *g:CommandTCursorLeftMap*
             |g:CommandTCursorLeftMap|  <Left>
                                      <C-h>

                                      *g:CommandTCursorRightMap*
            |g:CommandTCursorRightMap|  <Right>
                                      <C-l>

                                      *g:CommandTCursorEndMap*
              |g:CommandTCursorEndMap|  <C-e>

                                      *g:CommandTCursorStartMap*
            |g:CommandTCursorStartMap|  <C-a>

In addition to the options provided by Command-T itself, some of Vim's own
settings can be used to control behavior:

                                               *command-t-wildignore*
  |'wildignore'|                                 string (default: '')

      Vim's |'wildignore'| setting is used to determine which files should be
      excluded from listings. This is a comma-separated list of glob patterns.
      It defaults to the empty string, but common settings include "*.o,*.obj"
      (to exclude object files) or "**/.git/*,**/.svn/*" (to exclude SCM
      metadata directories). For example:

        :set wildignore+=*.o,*.obj

      A pattern such as "vendor/rails/**" would exclude all files and
      subdirectories inside the "vendor/rails" directory (relative to
      directory Command-T starts in).

      See the |'wildignore'| documentation for more information.

      If you want to influence Command-T's file exclusion behavior without
      changing your global |'wildignore'| setting, you can use the
      |g:CommandTWildIgnore| setting to apply an override that takes effect
      only during Command-T searches.

      Note that there are some differences among file scanners
      (see |g:CommandTFileScanner|) with respect to 'wildignore' handling:

      - The default "ruby" scanner explores the filesystem recursively using a
        depth-first search, and any directory (or subdirectory) which matches
        the 'wildignore' pattern is not explored. So, if your 'wildignore'
        contains "node_modules" then that entire sub-hierarchy will be
        ignored. Additionally, wildcard patterns like "node_modules/**" or
        "**/node_modules/*" will cause the entire sub-hierarchy to be ignored.

      - The "git" and "find" scanners apply 'wildignore' filtering only after
        completing their scans. Filtering only applies to files and not
        directories. This means that in the "node_modules" example case, the
        "node_modules" directory is not considered itself, and when we examine
        a file like "node_modules/foo/bar" the "node_modules" pattern does
        not match it (because "bar" does not match it). To exclude
        any "node_modules" directory anywhere in the hierarchy and all of its
        descendants we must use a pattern like "**/node_modules/*". To do this
        only for a top-level "node_modules", use "node_modules/**".

      - The "watchman" scanner is intended for use with massive hierarchies
        where speed is of the utmost import, so it doesn't consult
        'wildignore' at all.


FAQ                                             *command-t-faq*

Why does my build fail with "unknown argument -multiply_definedsuppress"? ~

You may see this on OS X Mavericks when building with the Clang compiler
against the system Ruby. This is an unfortunate Apple bug that breaks
compilation of many Ruby gems with native extensions on Mavericks. It has been
worked around in the upstream Ruby version, but won't be fixed in OS X until
Apple updates their supplied version of Ruby (most likely this won't be until
the next major release):

  https://bugs.ruby-lang.org/issues/9624

Workarounds include building your own Ruby (and then your own Vim and
Command-T), or more simply, building with the following `ARCHFLAGS` set:

  ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future ruby extconf.rb
  make

Why can't I open in a split with <C-CR> and <C-s> in the terminal? ~

It's likely that <C-CR> won't work in most terminals, because the keycode that
is sent to processes running inside them is identical to <CR>; when you type
<C-CR>, terminal Vim literally "sees" <CR>. Unfortunately, there is no
workaround for this.

If you find that <C-s> also doesn't work the most likely explanation is that
XON/XOFF flow control is enabled; this is the default in many environments.
This means that when you press <C-s> all input to the terminal is suspended
until you release it by hitting <C-q>. While input is suspended you may think
your terminal has frozen, but it hasn't.

To disable flow control, add the following to your `.zshrc` or
`.bash_profile`:

  stty -ixon

See the `stty` man page for more details.

Why doesn't the Escape key close the match listing in terminal Vim? ~

In some terminals such as xterm the Escape key misbehaves, so Command-T
doesn't set up a mapping for it. If you want to try using the escape key
anyway, you can add something like the following to your `~/.vimrc` file:

  if &term =~ "xterm" || &term =~ "screen"
    let g:CommandTCancelMap = ['<ESC>', '<C-c>']
  endif

This configuration has worked for me with recent versions of Vim on multiple
platforms (OS X, CentOS etc).


TIPS                                            *command-t-tips*

Working with very large repositories ~

One of the primary motivations for writing Command-T was to get fast, robust
high-quality matches even on large hierarchies. The larger the hierarchy, the
more important having good file navigation becomes. This is why Command-T's
performance-critical sections are written in C. This requires a compilation
step and makes Command-T harder to install than similar plug-ins which are
written in pure Vimscript, and can be a disincentive against use. This is a
conscious trade-off; the goal isn't to have as many users as possible, but
rather to provide the best performance at the highest quality.

The speed of the core is high enough that Command-T can afford to burn a bunch
of extra cycles -- using its recursive matching algorithm -- looking for a
higher-quality, more intuitive ranking of search results. Again, the larger
the hierarchy, the more important the quality of result ranking becomes.

Nevertheless, for extremely large hierarchies (of the order of 500,000 files)
some tuning is required in order to get useful and usable performance levels.
Here are some useful example settings:

    let g:CommandTMaxHeight = 30

You want the match listing window to be large enough that you can get useful
feedback about how your search query is going; in large hierarchies there may
be many, many matches for a given query. At the same time, you don't want Vim
wasting valuable cycles repainting a large portion of the screen area,
especially on a large display. Setting the limit to 30 or similar is a
reasonable compromise.

    let g:CommandTMaxFiles = 500000

The default limit of 30,000 files prevents Command-T from "seeing" many of the
files in a large directory hierarchy so you need to increase this limit.

    let g:CommandTInputDebounce = 200

Wait for 200ms of keyboard inactivity before computing search results. For
example, if you are enter "foobar" quickly (ie. within 1 second), there is
little sense in fetching the results for "f", "fo", "foo", "foob", "fooba" and
finally "foobar". Instead, we can just fetch the results for "foobar". This
setting trades off some immediate responsiveness at the micro level for
better performance (real and perceived) and a better search experience
overall.

    let g:CommandTFileScanner = 'watchman'

On a large hierarchy with of the order of 500,000 files, scanning a directory
tree with a tool like the `find` executable may take literally minutes with a
cold cache. Once the cache is warm, the same `find` run may take only a second
or two. Command-T provides a "find" scanner to leverage this performance, but
there is still massive overhead in passing the results through Vim internal
functions that apply 'wildignore' settings and such, so for truly immense
repos the "watchman" scanner is the tool of choice.

This scanner delegates the task of finding files to Facebook's `watchman` tool
(https://github.com/facebook/watchman), which can return results for a 500,000
file hierarchy within about a second.

Note that Watchman has a range of configuration options that can be applied by
files such as `/etc/watchman.json` or per-direcory `.watchmanconfig` files and
which may affect how Command-T works. For example, if your configuration has a
`root_restrict_files` setting that makes Watchman only work with roots that
look like Git or Mercurial repos, then Command-T will fall back to using the
"find" scanner any time you invoke it on a non-repo directory. For
simplicity's sake, it is probably a good idea to use Vim and Command-T
anchored at the root level of your repository in any case.

    let g:CommandTMaxCachedDirectories = 10

Command-T will internally cache up to 10 different directories, so even if you
|cd| repeatedly, it should only need to scan each directory once.

    let g:CommandTSmartCase = 1

Makes Command-T perform case-sensitive matching whenever the search pattern
includes an uppercase letter. This allows you to narrow the search results
listing with fewer keystrokes. See also |g:CommandTIgnoreCase|.

It's advisable to keep a long-running Vim instance in place and let it cache
the directory listings rather than repeatedly closing and re-opening Vim in
order to edit every file. On those occasions when you do need to flush the
cache (ie. with |CommandTFlush| or <C-f> in the match listing window), use of
the Watchman scanner should make the delay barely noticeable.

As noted in the introduction, Command-T works best when you adopt a
"path-centric" mentality. This is especially true on very large hierarchies.
For example, if you're looking for a file at:

  lib/third-party/adapters/restful-services/foobar/foobar-manager.js

you'll be able to narrow your search results down more narrowly if you search
with a query like "librestfoofooman" than "foobar-manager.js". This evidently
requires that you know where the file you're wanting to open exists, but
again, this is a concious design decision: Command-T is made to enable people
who know what they want to open and where it is to open it as quickly as
possible; other tools such as NERDTree exist for visually exploring an unknown
hierarchy.

Over time, you will get a feel for how economical you can afford to be with
your search queries in a given repo. In the example above, if "foo" is not a
very common pattern in your hierarchy, then you may find that you can find
what you need with a very concise query such as "foomanjs". With time, this
kind of ongoing calibration will come quite naturally.

Finally, it is important to be on a relatively recent version of Command-T to
fully benefit from the available performance enhancements:

- version 1.10 (July 2014) added the |g:CommandTIgnoreCase| and
  |g:CommandTSmartCase| options
- version 1.9 (May 2014) tweaked memoization algorithm for a 10% speed boost
- version 1.8 (March 2014) sped up the Watchman file scanner by switching its
  communication from the JSON to the binary Watchman protocol
- version 1.7 (February 2014) added the |g:CommandTInputDebounce| and
  |g:CommandTFileScanner| settings, along with support for the Watchman file
  scanner
- version 1.6 (December 2013) added parallelized search
- version 1.5 (September 2013) added memoization to the matching algorithm,
  improving general performance on large hierarchies, but delivering
  spectacular gains on hierarchies with "pathological" characteristics that
  lead the algorithm to exhibit degenerate behavior

AUTHORS                                         *command-t-authors*

Command-T is written and maintained by Greg Hurrell <greg@hurrell.net>.
Other contributors that have submitted patches include (in alphabetical
order):

  Abhinav Gupta                   Noon Silk
  Aleksandrs Ļedovskis            Ole Petter Bang
  Andy Waite                      Patrick Hayes
  Anthony Panozzo                 Paul Jolly
  Artem Nezvigin                  Pavel Sergeev
  Ben Boeckel                     Rainux Luo
  Ben Osheroff                    Richard Feldman
  Daniel Hahler                   Roland Puntaier
  David Szotten                   Ross Lagerwall
  Emily Strickland                Scott Bronson
  Felix Tjandrawibawa             Seth Fowler
  Gary Bernhardt                  Sherzod Gapirov
  Ivan Ukhov                      Shlomi Fish
  Jacek Wysocki                   Steven Moazami
  Jeff Kreeftmeijer               Sung Pae
  Kevin Webster                   Thomas Pelletier
  Lucas de Vries                  Ton van den Heuvel
  Marcus Brito                    Victor Hugo Borja
  Marian Schubert                 Vlad Seghete
  Matthew Todd                    Vít Ondruch
  Mike Lundy                      Woody Peterson
  Nadav Samet                     Yan Pritzker
  Nate Kane                       Yiding Jia
  Nicholas Alpi                   Zak Johnson
  Nikolai Aleksandrovich Pavlov

As this was the first Vim plug-in I had ever written I was heavily influenced
by the design of the LustyExplorer plug-in by Stephen Bach, which I understand
was one of the largest Ruby-based Vim plug-ins at the time.

While the Command-T codebase doesn't contain any code directly copied from
LustyExplorer, I did use it as a reference for answers to basic questions (like
"How do you do 'X' in a Ruby-based Vim plug-in?"), and also copied some basic
architectural decisions (like the division of the code into Prompt, Settings
and MatchWindow classes).

LustyExplorer is available from:

  http://www.vim.org/scripts/script.php?script_id=1890


DEVELOPMENT                                     *command-t-development*

Development in progress can be inspected via the project's Git web-based
repository browser at:

  https://wincent.com/repos/command-t

the clone URL for which is:

  git://git.wincent.com/command-t.git

A mirror exists on GitHub, which is automatically updated once per hour from
the authoritative repository:

  https://github.com/wincent/command-t

Patches are welcome via the usual mechanisms (pull requests, email, posting to
the project issue tracker etc).

As many users choose to track Command-T using Pathogen or similar, which often
means running a version later than the last official release, the intention is
that the "master" branch should be kept in a stable and reliable state as much
as possible.

Riskier changes are first cooked on the "next" branch for a period before
being merged into master. You can track this branch if you're feeling wild and
experimental, but note that the "next" branch may periodically be rewound
(force-updated) to keep it in sync with the "master" branch after each
official release.


WEBSITE                                         *command-t-website*

The official website for Command-T is:

  https://wincent.com/products/command-t

The latest release will always be available from there.

A copy of each release is also available from the official Vim scripts site
at:

  http://www.vim.org/scripts/script.php?script_id=3025

Bug reports should be submitted to the issue tracker at:

  https://wincent.com/issues


LICENSE                                         *command-t-license*

Copyright 2010-2015 Greg Hurrell. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

HISTORY                                         *command-t-history*

1.13 (29 April 2015)

- avoid "W10: Warning: Changing a readonly file" when starting Vim in
  read-only mode (ie. as `view` or with the `-R` option)
- fix infinite loop on |<Tab>| (regression introduced in 1.12)

1.12 (9 April 2015)

- add |:CommandTLoad| command
- fix rare failure to restore cursor color after closing Command-T (patch from
  Vlad Seghete)
- doc fixes and updates (patches from Daniel Hahler and Nicholas T.)
- make it possible to force reloading of the plug-in (patch from Daniel
  Hahler)
- add |g:CommandTEncoding| option, to work around rare encoding compatibility
  issues
- fix error restoring cursor highlights involving some configurations (patch
  from Daniel Hahler)
- skip set-up of |<Esc>| key mapping on rxvt terminals (patch from Daniel
  Hahler)
- add |g:CommandTGitScanSubmodules| option, which can be used to recursively
  scan submodules when the "git" file scanner is used (patch from Ben Boeckel)
- fix for not falling back to "find"-based scanner when a Watchman-related
  error occurs

1.11.4 (4 November 2014)

- fix infinite loop on Windows when |g:CommandTTraverseSCM| is set to a value
  other than "pwd" (bug present since 1.11)
- handle unwanted split edgecase when |'hidden'| is set, the current buffer is
  modified, and it is visible in more than one window

1.11.3 (10 October 2014)

- ignore impromperly encoded filenames (patch from Sherzod Gapirov)
- fix failure to update path when using |:cd| in conjunction with
  |g:CommandTTraverseSCM| set to "pwd" (bug present since 1.11.2)

1.11.2 (2 September 2014)

- fix error while using Command-T outside of an SCM repo (bug present since
  1.11.1)

1.11.1 (29 August 2014)

- compatibility fixes with Ruby 1.8.6 (patch from Emily Strickland)
- compatibility fixes with Ruby 1.8.5
- fix 'wildignore' being ignored (bug present since 1.11)
- fix current working directory being ignored when |g:CommandTTraverseSCM| is
  set to "pwd" (bug present since 1.11)
- performance improvements

1.11 (15 August 2014)

- improve edge-case handling in match results window code (patches from
  Richard Feldman)
- add "git" file scanner (patch from Patrick Hayes)
- speed-up when 'wildignore' is unset (patch from Patrick Hayes)
- add |g:CommandTTraverseSCM| setting which anchors Command-T's file finder to
  the nearest SCM directory (based on patches from David Szotten and Ben
  Osheroff)
- add AppStream metadata (patch from Vít Ondruch)

1.10 (15 July 2014)

- improve tag finder performance by caching tag lists (patch from Artem
  Nezvigin)
- consider the |'autowriteall'| option when deciding whether to open a file in
  a split
- make selection acceptance commands configurable (patch from Ole Petter Bang)
- add <C-w> mapping to delete previous word of the match prompt (patch from
  Kevin Webster)
- try harder to always clear status line after closing the match listing
  (patch from Ton van den Heuvel)
- don't allow MRU autocommands to produce errors when the extension has not
  been compiled
- add |g:CommandTIgnoreCase| and |g:CommandTSmartCase| options, providing
  support for case-sensitive matching (based on patch from Jacek Wysocki)

1.9.1 (30 May 2014)

- include the file in the release vimball archive that was missing from the
  1.9 release

1.9 (25 May 2014)

- improved startup time using Vim's autload mechanism (patch from Ross
  Lagerwall)
- added MRU (most-recently-used) buffer finder (patch from Ton van den Heuvel)
- fixed edge case in matching algorithm which could cause spurious matches
  with queries containing repeated characters
- fixed slight positive bias in the match scoring algorithm's weighting of
  matching characters based on distance from last match
- tune memoization in match scoring algorithm, yielding a more than 10% speed
  boost

1.8 (31 March 2014)

- taught Watchman file scanner to use the binary protocol instead of JSON,
  roughly doubling its speed
- build changes to accommodate MinGW (patch from Roland Puntaier)

1.7 (9 March 2014)

- added |g:CommandTInputDebounce|, which can be used to improve responsiveness
  in large file hierarchies (based on patch from Yiding Jia)
- added a potentially faster file scanner which uses the `find` executable
  (based on patch from Yiding Jia)
- added a file scanner that knows how to talk to Watchman
  (https://github.com/facebook/watchman)
- added |g:CommandTFileScanner|, which can be used to switch file scanners
- fix processor count detection on some platforms (patch from Pavel Sergeev)

1.6.1 (22 December 2013)

- defer processor count detection until runtime (makes it possible to sensibly
  build Command-T on one machine and use it on another)

1.6 (16 December 2013)

- on systems with POSIX threads (such as OS X and Linux), Command-T will use
  threads to compute match results in parallel, resulting in a large speed
  boost that is especially noticeable when navigating large projects

1.5.1 (23 September 2013)

- exclude large benchmark fixture file from source exports (patch from Vít
  Ondruch)

1.5 (18 September 2013)

- don't scan "pathological" filesystem structures (ie. circular or
  self-referential symlinks; patch from Marcus Brito)
- gracefully handle files starting with "+" (patch from Ivan Ukhov)
- switch default selection highlight color for better readability (suggestion
  from André Arko), but make it possible to configure via the
  |g:CommandTHighlightColor| setting
- added a mapping to take the current matches and put then in the quickfix
  window
- performance improvements, particularly noticeable with large file
  hierarchies
- added |g:CommandTWildIgnore| setting (patch from Paul Jolly)

1.4 (20 June 2012)

- added |:CommandTTag| command (patches from Noon Silk)
- turn off |'colorcolumn'| and |'relativenumber'| in the match window (patch
  from Jeff Kreeftmeijer)
- documentation update (patch from Nicholas Alpi)
- added |:CommandTMinHeight| option (patch from Nate Kane)
- highlight (by underlining) matched characters in the match listing (requires
  Vim to have been compiled with the +conceal feature, which is available in
  Vim 7.3 or later; patch from Steven Moazami)
- added the ability to flush the cache while the match window is open using
  <C-f>

1.3.1 (18 December 2011)

- fix jumplist navigation under Ruby 1.9.x (patch from Woody Peterson)

1.3 (27 November 2011)

- added the option to maintain multiple caches when changing among
  directories; see the accompanying |g:CommandTMaxCachedDirectories| setting
- added the ability to navigate using the Vim jumplist (patch from Marian
  Schubert)

1.2.1 (30 April 2011)

- Remove duplicate copy of the documentation that was causing "Duplicate tag"
  errors
- Mitigate issue with distracting blinking cursor in non-GUI versions of Vim
  (patch from Steven Moazami)

1.2 (30 April 2011)

- added |g:CommandTMatchWindowReverse| option, to reverse the order of items
  in the match listing (patch from Steven Moazami)

1.1b2 (26 March 2011)

- fix a glitch in the release process; the plugin itself is unchanged since
  1.1b

1.1b (26 March 2011)

- add |:CommandTBuffer| command for quickly selecting among open buffers

1.0.1 (5 January 2011)

- work around bug when mapping |:CommandTFlush|, wherein the default mapping
  for |:CommandT| would not be set up
- clean up when leaving the Command-T buffer via unexpected means (such as
  with <C-W k> or similar)

1.0 (26 November 2010)

- make relative path simplification work on Windows

1.0b (5 November 2010)

- work around platform-specific Vim 7.3 bug seen by some users (wherein
  Vim always falsely reports to Ruby that the buffer numbers is 0)
- re-use the buffer that is used to show the match listing, rather than
  throwing it away and recreating it each time Command-T is shown; this
  stops the buffer numbers from creeping up needlessly

0.9 (8 October 2010)

- use relative paths when opening files inside the current working directory
  in order to keep buffer listings as brief as possible (patch from Matthew
  Todd)

0.8.1 (14 September 2010)

- fix mapping issues for users who have set |'notimeout'| (patch from Sung
  Pae)

0.8 (19 August 2010)

- overrides for the default mappings can now be lists of strings, allowing
  multiple mappings to be defined for any given action
- <Leader>t mapping only set up if no other map for |:CommandT| exists
  (patch from Scott Bronson)
- prevent folds from appearing in the match listing
- tweaks to avoid the likelihood of "Not enough room" errors when trying to
  open files
- watch out for "nil" windows when restoring window dimensions
- optimizations (avoid some repeated downcasing)
- move all Ruby files under the "command-t" subdirectory and avoid polluting
  the "Vim" module namespace

0.8b (11 July 2010)

- large overhaul of the scoring algorithm to make the ordering of returned
  results more intuitive; given the scope of the changes and room for
  optimization of the new algorithm, this release is labelled as "beta"

0.7 (10 June 2010)

- handle more |'wildignore'| patterns by delegating to Vim's own |expand()|
  function; with this change it is now viable to exclude patterns such as
  'vendor/rails/**' in addition to filename-only patterns like '*.o' and
  '.git' (patch from Mike Lundy)
- always sort results alphabetically for empty search strings; this eliminates
  filesystem-specific variations (patch from Mike Lundy)

0.6 (28 April 2010)

- |:CommandT| now accepts an optional parameter to specify the starting
  directory, temporarily overriding the usual default of Vim's |:pwd|
- fix truncated paths when operating from root directory

0.5.1 (11 April 2010)

- fix for Ruby 1.9 compatibility regression introduced in 0.5
- documentation enhancements, specifically targetted at Windows users

0.5 (3 April 2010)

- |:CommandTFlush| now re-evaluates settings, allowing changes made via |let|
  to be picked up without having to restart Vim
- fix premature abort when scanning very deep directory hierarchies
- remove broken |<Esc>| key mapping on vt100 and xterm terminals
- provide settings for overriding default mappings
- minor performance optimization

0.4 (27 March 2010)

- add |g:CommandTMatchWindowAtTop| setting (patch from Zak Johnson)
- documentation fixes and enhancements
- internal refactoring and simplification

0.3 (24 March 2010)

- add |g:CommandTMaxHeight| setting for controlling the maximum height of the
  match window (patch from Lucas de Vries)
- fix bug where |'list'| setting might be inappropriately set after dismissing
  Command-T
- compatibility fix for different behaviour of "autoload" under Ruby 1.9.1
- avoid "highlight group not found" warning when run under a version of Vim
  that does not have syntax highlighting support
- open in split when opening normally would fail due to |'hidden'| and
  |'modified'| values

0.2 (23 March 2010)

- compatibility fixes for compilation under Ruby 1.9 series
- compatibility fixes for compilation under Ruby 1.8.5
- compatibility fixes for Windows and other non-UNIX platforms
- suppress "mapping already exists" message if <Leader>t mapping is already
  defined when plug-in is loaded
- exclude paths based on |'wildignore'| setting rather than a hardcoded
  regular expression

0.1 (22 March 2010)

- initial public release

------------------------------------------------------------------------------
vim:tw=78:ft=help:
