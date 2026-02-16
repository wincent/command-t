-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')
local fixtures = require('wincent.commandt.test.fixtures')

--- @alias Matcher {
---   match: (fun(query: string): string[]),
---   _scanner: userdata,
---   _matcher: userdata,
--- }

describe('matcher.c', function()
  local lib = require('wincent.commandt.private.lib')

  --- @param paths string[]
  --- @param options? {
  ---   height?: number,
  ---   ignore_case?: boolean,
  ---   ignore_spaces?: boolean,
  ---   smart_case?: boolean,
  --- }
  --- @return Matcher
  local function get_matcher(paths, options)
    options = options or {}
    local scanner = lib.scanner_new_copy(paths)
    local matcher = lib.matcher_new(scanner, options)
    return {
      match = function(query)
        local results = lib.matcher_run(matcher, query)
        local strings = {}
        for k = 0, results.match_count - 1 do
          local str = results.matches[k]
          table.insert(strings, ffi.string(str.contents, str.length))
        end
        return strings
      end,
      _scanner = scanner, -- Prevent premature GC.
      _matcher = matcher, -- Prevent premature GC.
    }
  end

  context('with an empty scanner', function()
    --- @type Matcher
    local matcher = nil

    before(function()
      matcher = get_matcher({})
    end)

    it('returns an empty list given an empty query', function()
      expect(matcher.match('')).to_equal({})
    end)

    it('returns an empty list given a non-empty query', function()
      expect(matcher.match('foo')).to_equal({})
    end)
  end)

  context('with a non-empty scanner', function()
    it('returns matching paths', function()
      local matcher = get_matcher({ 'foo/bar', 'foo/baz', 'bing' })
      expect(matcher.match('z')).to_equal({ 'foo/baz' })
      expect(matcher.match('bg')).to_equal({ 'bing' })
    end)

    it('returns an empty list when nothing matches', function()
      local matcher = get_matcher({ 'foo/bar', 'foo/baz', 'bing' })
      expect(matcher.match('xyz')).to_equal({})
    end)

    it('considers the empty string to match everything', function()
      local matcher = get_matcher({ 'foo' })
      expect(matcher.match('')).to_equal({ 'foo' })
    end)

    context('`ignore_case = false` and `smart_case = false`', function()
      it('performs case-sensitive matching', function()
        local matcher = get_matcher({ 'Foo' }, {
          ignore_case = false,
          smart_case = false,
        })
        expect(matcher.match('F')).to_equal({ 'Foo' })
        expect(matcher.match('o')).to_equal({ 'Foo' })
        expect(matcher.match('f')).to_equal({})
        expect(matcher.match('O')).to_equal({})
        expect(matcher.match('b')).to_equal({})
      end)
    end)

    context('`ignore_case = false` and `smart_case = true`', function()
      it('performs case-sensitive matching', function()
        local matcher = get_matcher({ 'Foo' }, {
          ignore_case = false,
          smart_case = true,
        })
        expect(matcher.match('F')).to_equal({ 'Foo' })
        expect(matcher.match('o')).to_equal({ 'Foo' })
        expect(matcher.match('f')).to_equal({})
        expect(matcher.match('O')).to_equal({})
        expect(matcher.match('b')).to_equal({})
      end)
    end)

    context('`ignore_case = true` and `smart_case = false`', function()
      it('performs case-insensitive matching', function()
        local matcher = get_matcher({ 'Foo' }, {
          ignore_case = true,
          smart_case = false,
        })
        expect(matcher.match('F')).to_equal({ 'Foo' })
        expect(matcher.match('f')).to_equal({ 'Foo' })
        expect(matcher.match('O')).to_equal({ 'Foo' })
        expect(matcher.match('o')).to_equal({ 'Foo' })
        expect(matcher.match('b')).to_equal({})
      end)
    end)

    context('`ignore_case = true` and `smart_case = true`', function()
      it('performs case-insensitive matching unless search pattern contains uppercase characters', function()
        local matcher = get_matcher({ 'Foo' }, {
          ignore_case = true,
          smart_case = true,
        })
        expect(matcher.match('F')).to_equal({ 'Foo' })
        expect(matcher.match('f')).to_equal({ 'Foo' })
        expect(matcher.match('O')).to_equal({})
        expect(matcher.match('o')).to_equal({ 'Foo' })
        expect(matcher.match('b')).to_equal({})
      end)
    end)

    it('defaults `ignore_case` and `smart_case` to `true`', function()
      local matcher = get_matcher({ 'Foo' })
      expect(matcher.match('F')).to_equal({ 'Foo' })
      expect(matcher.match('f')).to_equal({ 'Foo' })
      expect(matcher.match('O')).to_equal({})
      expect(matcher.match('o')).to_equal({ 'Foo' })
      expect(matcher.match('b')).to_equal({})
    end)

    -- We don't expect to see these in practice, but we still want to test it.
    it('gracefully handles empty haystacks', function()
      local matcher = get_matcher({ '', 'foo' })
      expect(matcher.match('')).to_equal({ '', 'foo' })
      expect(matcher.match('f')).to_equal({ 'foo' })
    end)

    it('does not consider mere substrings of the query string to be a match', function()
      local matcher = get_matcher({ 'foo' })
      expect(matcher.match('foo...')).to_equal({})
    end)

    it('prioritizes shorter paths over longer ones', function()
      local matcher = get_matcher({
        'articles_controller_spec.rb',
        'article.rb',
      })
      expect(matcher.match('art')).to_equal({
        'article.rb',
        'articles_controller_spec.rb',
      })
    end)

    it('prioritizes matches after "/"', function()
      local matcher = get_matcher({ 'fooobar', 'foo/bar' })
      expect(matcher.match('b')).to_equal({ 'foo/bar', 'fooobar' })

      -- Note that "/" beats "_".
      matcher = get_matcher({ 'foo_bar', 'foo/bar' })
      expect(matcher.match('b')).to_equal({ 'foo/bar', 'foo_bar' })

      -- "/" also beats "-".
      matcher = get_matcher({ 'foo-bar', 'foo/bar' })
      expect(matcher.match('b')).to_equal({ 'foo/bar', 'foo-bar' })

      -- And numbers.
      matcher = get_matcher({ 'foo9bar', 'foo/bar' })
      expect(matcher.match('b')).to_equal({ 'foo/bar', 'foo9bar' })

      -- And periods.
      matcher = get_matcher({ 'foo.bar', 'foo/bar' })
      expect(matcher.match('b')).to_equal({ 'foo/bar', 'foo.bar' })

      -- And spaces.
      matcher = get_matcher({ 'foo bar', 'foo/bar' })
      expect(matcher.match('b')).to_equal({ 'foo/bar', 'foo bar' })
    end)

    it('prioritizes matches after "-"', function()
      local matcher = get_matcher({ 'fooobar', 'foo-bar' })
      expect(matcher.match('b')).to_equal({ 'foo-bar', 'fooobar' })

      -- "-" also beats ".".
      matcher = get_matcher({ 'foo.bar', 'foo-bar' })
      expect(matcher.match('b')).to_equal({ 'foo-bar', 'foo.bar' })
    end)

    it('prioritizes matches after "_"', function()
      local matcher = get_matcher({ 'fooobar', 'foo_bar' })
      expect(matcher.match('b')).to_equal({ 'foo_bar', 'fooobar' })

      -- "_" also beats ".".
      matcher = get_matcher({ 'foo.bar', 'foo_bar' })
      expect(matcher.match('b')).to_equal({ 'foo_bar', 'foo.bar' })
    end)

    it('prioritizes matches after " "', function()
      local matcher = get_matcher({ 'fooobar', 'foo bar' })
      expect(matcher.match('b')).to_equal({ 'foo bar', 'fooobar' })

      -- " " also beats ".".
      matcher = get_matcher({ 'foo.bar', 'foo bar' })
      expect(matcher.match('b')).to_equal({ 'foo bar', 'foo.bar' })
    end)

    it('prioritizes matches after numbers', function()
      local matcher = get_matcher({ 'fooobar', 'foo9bar' })
      expect(matcher.match('b')).to_equal({ 'foo9bar', 'fooobar' })

      -- Numbers also beat ".".
      matcher = get_matcher({ 'foo.bar', 'foo9bar' })
      expect(matcher.match('b')).to_equal({ 'foo9bar', 'foo.bar' })
    end)

    it('prioritizes matches after periods', function()
      local matcher = get_matcher({ 'fooobar', 'foo.bar' })
      expect(matcher.match('b')).to_equal({ 'foo.bar', 'fooobar' })
    end)

    it('prioritizes matching capitals following lowercase', function()
      local matcher = get_matcher({ 'foobar', 'fooBar' })
      expect(matcher.match('b')).to_equal({ 'fooBar', 'foobar' })
    end)

    it('prioritizes matches earlier in the string', function()
      local matcher = get_matcher({ '******b*', '**b*****' })
      expect(matcher.match('b')).to_equal({ '**b*****', '******b*' })
    end)

    it('prioritizes matches closer to previous matches', function()
      local matcher = get_matcher({ '**b***c*', '**bc****' })
      expect(matcher.match('bc')).to_equal({ '**bc****', '**b***c*' })
    end)

    it('scores alternative matches of same path differently', function()
      -- ie: "app/controllers/articles_controller.rb"
      local matcher = get_matcher({
        'a**/****r******/**t*c***_*on*******.**',
        '***/***********/art*****_con*******.**',
      })
      expect(matcher.match('artcon')).to_equal({
        '***/***********/art*****_con*******.**',
        'a**/****r******/**t*c***_*on*******.**',
      })
    end)

    it('provides intuitive results for "artcon" and "articles_controller"', function()
      local matcher = get_matcher({
        'app/controllers/heartbeat_controller.rb',
        'app/controllers/articles_controller.rb',
      })
      expect(matcher.match('artcon')).to_equal({
        'app/controllers/articles_controller.rb',
        'app/controllers/heartbeat_controller.rb',
      })
    end)

    it('provides intuitive results for "aca" and "a/c/articles_controller"', function()
      local matcher = get_matcher({
        'app/controllers/heartbeat_controller.rb',
        'app/controllers/articles_controller.rb',
      })
      expect(matcher.match('aca')).to_equal({
        'app/controllers/articles_controller.rb',
        'app/controllers/heartbeat_controller.rb',
      })
    end)

    it('provides intuitive results for "d" and "doc/command-t.txt"', function()
      local matcher = get_matcher({
        'TODO',
        'doc/command-t.txt',
      })
      expect(matcher.match('d')).to_equal({
        'doc/command-t.txt',
        'TODO',
      })
    end)

    it('provides intuitive results for "do" and "doc/command-t.txt"', function()
      local matcher = get_matcher({
        'TODO',
        'doc/command-t.txt',
      })
      expect(matcher.match('do')).to_equal({
        'doc/command-t.txt',
        'TODO',
      })
    end)

    it('provides intuitive results for "matchh" search', function()
      -- Regression introduced in 187bc18.
      local matcher = get_matcher({
        'vendor/bundle/ruby/1.8/gems/rspec-expectations-2.14.5/spec/rspec/matchers/has_spec.rb',
        'ruby/command-t/match.h',
      })
      expect(matcher.match('matchh')).to_equal({
        'ruby/command-t/match.h',
        'vendor/bundle/ruby/1.8/gems/rspec-expectations-2.14.5/spec/rspec/matchers/has_spec.rb',
      })
    end)

    it('provides intuitive results for "relqpath" search', function()
      -- Another regression.
      local matcher = get_matcher({
        '*l**/e*t*t*/atla*/patter**/E*tAtla***el****q*e*e***al**at***HelperTra*t.php',
        'static_upstream/relay/query/RelayQueryPath.js',
      })
      expect(matcher.match('relqpath')).to_equal({
        'static_upstream/relay/query/RelayQueryPath.js',
        '*l**/e*t*t*/atla*/patter**/E*tAtla***el****q*e*e***al**at***HelperTra*t.php',
      })
    end)

    it('provides intuitive results for "controller" search', function()
      -- Another regression.
      local matcher = get_matcher({
        'spec/command-t/controller_spec.rb',
        'ruby/command-t/controller.rb',
      })
      expect(matcher.match('controller')).to_equal({
        'ruby/command-t/controller.rb',
        'spec/command-t/controller_spec.rb',
      })
    end)

    it("doesn't incorrectly accept repeats of the last-matched character", function()
      -- https://github.com/wincent/Command-T/issues/82
      local matcher = get_matcher({ 'ash/system/user/config.h' })
      expect(matcher.match('usercc')).to_equal({})

      -- Simpler test case.
      matcher = get_matcher({ 'foobar' })
      expect(matcher.match('fooooo')).to_equal({})

      -- Minimal repro.
      matcher = get_matcher({ 'ab' })
      expect(matcher.match('aa')).to_equal({})
    end)

    it('ignores dotfiles by default', function()
      local matcher = get_matcher({ '.foo', '.bar' })
      expect(matcher.match('foo')).to_equal({})
    end)

    it('shows dotfiles if the query starts with a dot', function()
      local matcher = get_matcher({ '.foo', '.bar' })
      expect(matcher.match('.fo')).to_equal({ '.foo' })
    end)

    it("doesn't show dotfiles if the query contains a non-leading dot", function()
      local matcher = get_matcher({ '.foo.txt', '.bar.txt' })
      expect(matcher.match('f.t')).to_equal({})

      -- Counter-example.
      expect(matcher.match('.f.t')).to_equal({ '.foo.txt' })
    end)

    it('shows dotfiles when there is a non-leading dot that matches a leading dot within a path component', function()
      local matcher = get_matcher({ 'this/.secret/stuff.txt', 'something.else' })
      expect(matcher.match('t.sst')).to_equal({ 'this/.secret/stuff.txt' })
    end)

    it("doesn't show a dotfile just because there was a match at index 0", function()
      pending('fix: see ed01bc6') -- Bug exists in Ruby implementation as well.
      local matcher = get_matcher({ 'src/.flowconfig' })
      expect(matcher.match('s')).to_equal({})
    end)

    it('correctly scores the example from command-t#209', function()
      -- Related: https://github.com/wincent/command-t/issues/209
      local matcher = get_matcher({
        'app/assets/components/App/index.jsx',
        'app/assets/components/PrivacyPage/index.jsx',
        'app/views/api/docs/pagination/_index.md',
      })

      -- To be honest, I don't really like the ranking here, but with
      -- DEBUG_SCORING we see the calculations:
      --
      --           a       p       p       a       p       p       i       n       d
      --    a:  0.0684     -       -       -       -       -       -       -       -
      --    p:     -    0.1368     -       -       -       -       -       -       -
      --    p:     -       -    0.2051     -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    v:     -       -       -       -       -       -       -       -       -
      --    i:     -       -       -       -       -       -       -       -       -
      --    e:     -       -       -       -       -       -       -       -       -
      --    w:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    a:     -       -       -    0.2667     -       -       -       -       -
      --    p:     -       -       -       -    0.3350     -       -       -       -
      --    i:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    d:     -       -       -       -       -       -       -       -       -
      --    o:     -       -       -       -       -       -       -       -       -
      --    c:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    p:     -       -       -       -       -    0.3966     -       -       -
      --    a:     -       -       -       -       -       -       -       -       -
      --    g:     -       -       -       -       -       -       -       -       -
      --    i:     -       -       -       -       -       -    0.5880     -       -
      --    n:     -       -       -       -       -       -       -       -       -
      --    a:     -       -       -       -       -       -       -       -       -
      --    t:     -       -       -       -       -       -       -       -       -
      --    i:     -       -       -       -       -       -    0.5880     -       -
      --    o:     -       -       -       -       -       -       -       -       -
      --    n:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    _:     -       -       -       -       -       -       -       -       -
      --    i:     -       -       -       -       -       -    0.4513     -       -
      --    n:     -       -       -       -       -       -       -    0.5197     -
      --    d:     -       -       -       -       -       -       -       -    0.5880
      --    e:     -       -       -       -       -       -       -       -       -
      --    x:     -       -       -       -       -       -       -       -       -
      --    .:     -       -       -       -       -       -       -       -       -
      --    m:     -       -       -       -       -       -       -       -       -
      --    d:     -       -       -       -       -       -       -       -    0.5282
      --    Final score: 0.588034
      --
      --           a       p       p       a       p       p       i       n       d
      --    a:  0.0672     -       -       -       -       -       -       -       -
      --    p:     -    0.1344     -       -       -       -       -       -       -
      --    p:     -       -    0.2016     -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    a:     -       -       -    0.2620     -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    e:     -       -       -       -       -       -       -       -       -
      --    t:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    c:     -       -       -       -       -       -       -       -       -
      --    o:     -       -       -       -       -       -       -       -       -
      --    m:     -       -       -       -       -       -       -       -       -
      --    p:     -       -       -       -    0.5711     -       -       -       -
      --    o:     -       -       -       -       -       -       -       -       -
      --    n:     -       -       -       -       -       -       -       -       -
      --    e:     -       -       -       -       -       -       -       -       -
      --    n:     -       -       -       -       -       -       -       -       -
      --    t:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    P:     -       -       -       -    0.3225     -       -       -       -
      --    r:     -       -       -       -       -       -       -       -       -
      --    i:     -       -       -       -       -       -       -       -       -
      --    v:     -       -       -       -       -       -       -       -       -
      --    a:     -       -       -       -       -       -       -       -       -
      --    c:     -       -       -       -       -       -       -       -       -
      --    y:     -       -       -       -       -       -       -       -       -
      --    P:     -       -       -       -       -    0.3762     -       -       -
      --    a:     -       -       -       -       -       -       -       -       -
      --    g:     -       -       -       -       -       -       -       -       -
      --    e:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    i:     -       -       -       -       -       -    0.4367     -       -
      --    n:     -       -       -       -       -       -       -    0.5039     -
      --    d:     -       -       -       -       -       -       -       -    0.5711
      --    Final score: 0.571059
      --
      --           a       p       p       a       p       p       i       n       d
      --    a:  0.0698     -       -       -       -       -       -       -       -
      --    p:     -    0.5055     -       -       -       -       -       -       -
      --    p:     -    0.0960     -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    a:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    e:     -       -       -       -       -       -       -       -       -
      --    t:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    c:     -       -       -       -       -       -       -       -       -
      --    o:     -       -       -       -       -       -       -       -       -
      --    m:     -       -       -       -       -       -       -       -       -
      --    p:     -       -    0.1004     -       -       -       -       -       -
      --    o:     -       -       -       -       -       -       -       -       -
      --    n:     -       -       -       -       -       -       -       -       -
      --    e:     -       -       -       -       -       -       -       -       -
      --    n:     -       -       -       -       -       -       -       -       -
      --    t:     -       -       -       -       -       -       -       -       -
      --    s:     -       -       -       -       -       -       -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    A:     -       -       -    0.1633     -       -       -       -       -
      --    p:     -       -       -       -    0.2331     -       -       -       -
      --    p:     -       -       -       -       -    0.3029     -       -       -
      --    /:     -       -       -       -       -       -       -       -       -
      --    i:     -       -       -       -       -       -    0.3658     -       -
      --    n:     -       -       -       -       -       -       -    0.4356     -
      --    d:     -       -       -       -       -       -       -       -    0.5055
      --    Final score: 0.505476
      expect(matcher.match('appappind')).to_equal({
        'app/views/api/docs/pagination/_index.md',
        'app/assets/components/PrivacyPage/index.jsx',
        'app/assets/components/App/index.jsx',
      })
    end)

    it('correctly handles a limits', function()
      -- Regression introduced in 08f4ce135ab7abff, fixed in 41ca3dc2a87109d2b.
      --
      -- This probably isn't a minimal test, but it demonstrates what I was
      -- seeing prior to the fix. When using `fd` in ym dotfiles repo, it was
      -- returning about 3K files in a non-determinstic order. Given the order I
      -- captured in the fixtures file, the matcher was returning about 396
      -- results instead of the desired 400.
      local matcher = get_matcher(fixtures.dotfiles_fd, { height = 400 })
      expect(matcher.match('')).to_equal({
        'CHANGELOG.md',
        'CONTRIBUTING.md',
        'LICENSE.md',
        'README.md',
        'aspects/aur/README.md',
        'aspects/aur/aspect.ts',
        'aspects/aur/files/etc/modprobe.d/it87.conf',
        'aspects/aur/files/etc/modules-load.d/it87.conf',
        'aspects/aur/files/etc/sensors.d/gigabyte-x570.conf',
        'aspects/aur/index.ts',
        'aspects/automator/README.md',
        'aspects/automator/aspect.json',
        'aspects/automator/index.ts',
        'aspects/automator/support/Open in Terminal Vim.applescript',
        'aspects/automator/support/Open in Terminal Vim.js',
        'aspects/automount/README.md',
        'aspects/automount/aspect.json',
        'aspects/automount/index.ts',
        'aspects/avahi/README.md',
        'aspects/avahi/aspect.json',
        'aspects/avahi/index.ts',
        'aspects/backup/README.md',
        'aspects/backup/aspect.json',
        'aspects/backup/files/dump',
        'aspects/backup/files/snapshot',
        'aspects/backup/files/sync',
        'aspects/backup/index.ts',
        'aspects/bitcoin/README.md',
        'aspects/bitcoin/aspect.ts',
        'aspects/bitcoin/index.ts',
        'aspects/cron/README.md',
        'aspects/cron/aspect.json',
        'aspects/cron/index.ts',
        'aspects/cron/templates/check-git.sh.erb',
        'aspects/defaults/README.md',
        'aspects/defaults/aspect.json',
        'aspects/defaults/index.ts',
        'aspects/dotfiles/README.md',
        'aspects/dotfiles/aspect.json',
        'aspects/dotfiles/files/Library/Preferences/glow/glow.yml',
        'aspects/dotfiles/index.ts',
        'aspects/dotfiles/support/compile-zwc',
        'aspects/fonts/README.md',
        'aspects/fonts/aspect.json',
        'aspects/fonts/index.ts',
        'aspects/homebrew/README.md',
        'aspects/homebrew/aspect.json',
        'aspects/homebrew/index.ts',
        'aspects/homebrew/support/updateBrewfile.mts',
        'aspects/homebrew/templates/Brewfile.erb',
        'aspects/interception/README.md',
        'aspects/interception/aspect.json',
        'aspects/interception/index.ts',
        'aspects/interception/support/mac2linux/CMakeLists.txt',
        'aspects/interception/support/mac2linux/mac2linux.c',
        'aspects/interception/templates/50-realforce-layout.rules.erb',
        'aspects/interception/templates/dual-function-keys.yaml.erb',
        'aspects/interception/templates/udevmon.yaml.erb',
        'aspects/karabiner/aspect.json',
        'aspects/karabiner/files/bin/karabiner-boot.command',
        'aspects/karabiner/files/bin/karabiner-kill.command',
        'aspects/karabiner/index.ts',
        'aspects/karabiner/support/dry/Makefile',
        'aspects/karabiner/support/dry/main.c',
        'aspects/karabiner/support/karabiner-test.js',
        'aspects/karabiner/support/karabiner.js',
        'aspects/karabiner/templates/karabiner-sudoers.erb',
        'aspects/launchd/README.md',
        'aspects/launchd/aspect.json',
        'aspects/launchd/index.ts',
        'aspects/launchd/templates/run.plist.erb',
        'aspects/locale/README.md',
        'aspects/locale/aspect.json',
        'aspects/locale/index.ts',
        'aspects/meta/README.md',
        'aspects/meta/aspect.json',
        'aspects/meta/files/example.txt',
        'aspects/meta/global.ts',
        'aspects/meta/index.ts',
        'aspects/meta/templates/sample.txt.erb',
        'aspects/meta/tests.ts',
        'aspects/nix/README.md',
        'aspects/nix/aspect.ts',
        'aspects/nix/files/shell.nix',
        'aspects/nix/index.ts',
        'aspects/node/aspect.json',
        'aspects/node/index.ts',
        'aspects/nvim/aspect.json',
        'aspects/nvim/index.ts',
        'aspects/nvim/support/update-bundle',
        'aspects/nvim/support/update-help-tags',
        'aspects/pacman/README.md',
        'aspects/pacman/aspect.ts',
        'aspects/pacman/files/etc/pacman.conf',
        'aspects/pacman/files/etc/systemd/system/suspend@.service',
        'aspects/pacman/index.ts',
        'aspects/ruby/aspect.json',
        'aspects/ruby/index.ts',
        'aspects/shell/aspect.json',
        'aspects/shell/index.ts',
        'aspects/ssh/README.md',
        'aspects/ssh/aspect.json',
        'aspects/ssh/index.ts',
        'aspects/sshd/aspect.json',
        'aspects/sshd/index.ts',
        'aspects/systemd/README.md',
        'aspects/systemd/aspect.json',
        'aspects/systemd/index.ts',
        'aspects/violentmonkey/README.md',
        'aspects/violentmonkey/aspect.json',
        'aspects/violentmonkey/index.ts',
        'aspects/violentmonkey/templates/UserScripts/appgate/autoclose.user.js',
        'aspects/violentmonkey/templates/UserScripts/atlassian/suppressAI.user.js',
        'aspects/violentmonkey/templates/UserScripts/fastmail/suppressEscape.user.js',
        'aspects/violentmonkey/templates/UserScripts/github/enhanceReviewComments.user.js',
        'aspects/violentmonkey/templates/UserScripts/github/makeTextAreasBigger.user.js',
        'aspects/violentmonkey/templates/UserScripts/gmail/removeHighlighting.user.js',
        'aspects/violentmonkey/templates/UserScripts/twitter/bypassClickTracking.user.js',
        'aspects/violentmonkey/templates/UserScripts/twitter/hideLikeButtons.user.js',
        'aspects/violentmonkey/templates/UserScripts/youtube/unhideYouTubeInfo.user.js',
        'aspects/violentmonkey/templates/UserScripts/zoom/autocloseInterstitial.user.js',
        'aspects/violentmonkey/templates/apache2/users/user.conf.erb',
        'aspects/violentmonkey/templates/index.html',
        'bin/benchmark',
        'bin/check-format',
        'bin/common',
        'bin/format',
        'bin/n',
        'bin/node',
        'bin/test-terminal',
        'bin/tsc',
        'bin/update-themes',
        'bin/yarn',
        'contrib/arch-linux/README.md',
        'contrib/arch-linux/install-desktop.sh',
        'contrib/arch-linux/install-zbook.sh',
        'docs/PERFORMANCE.md',
        'fig.config.ts',
        'fig/Attributes.ts',
        'fig/Compiler.ts',
        'fig/Context.ts',
        'fig/ErrorWithMetadata.ts',
        'fig/HandlerRegistry.ts',
        'fig/README.md',
        'fig/Scanner.ts',
        'fig/TaskRegistry.ts',
        'fig/Unicode.ts',
        'fig/UnsupportedValueError.ts',
        'fig/VariableRegistry.ts',
        'fig/__tests__/Scanner-test.ts',
        'fig/__tests__/__fixtures__/sample',
        'fig/__tests__/compare-test.ts',
        'fig/__tests__/merge-test.ts',
        'fig/__tests__/path-test.ts',
        'fig/__tests__/regExpFromString-test.ts',
        'fig/__tests__/resource-test.ts',
        'fig/__tests__/stringify-test.ts',
        'fig/__tests__/template-test.ts',
        'fig/assert.ts',
        'fig/child_process.ts',
        'fig/compare.ts',
        'fig/console.ts',
        'fig/console/COLORS.ts',
        'fig/dedent.ts',
        'fig/dsl/attributes.ts',
        'fig/dsl/fail.ts',
        'fig/dsl/handler.ts',
        'fig/dsl/operations/__tests__/cron-test.ts',
        'fig/dsl/operations/__tests__/defaults-test.ts',
        'fig/dsl/operations/backup.ts',
        'fig/dsl/operations/command.ts',
        'fig/dsl/operations/cron.ts',
        'fig/dsl/operations/defaults.ts',
        'fig/dsl/operations/fetch.ts',
        'fig/dsl/operations/file.ts',
        'fig/dsl/operations/line.ts',
        'fig/dsl/operations/template.ts',
        'fig/dsl/options.ts',
        'fig/dsl/resource.ts',
        'fig/dsl/root.ts',
        'fig/dsl/skip.ts',
        'fig/dsl/task.ts',
        'fig/dsl/variable.ts',
        'fig/dsl/variables.ts',
        'fig/escapeRegExpPattern.ts',
        'fig/executable.ts',
        'fig/fs.ts',
        'fig/fs/stat.ts',
        'fig/fs/tempdir.ts',
        'fig/fs/tempfile.ts',
        'fig/fs/tempname.ts',
        'fig/getAspectFromCallers.ts',
        'fig/getCallers.ts',
        'fig/getOptions.ts',
        'fig/globToRegExp.ts',
        'fig/index.ts',
        'fig/lock.ts',
        'fig/main.mts',
        'fig/merge.ts',
        'fig/package.json',
        'fig/path.ts',
        'fig/posix/__tests__/chmod-test.ts',
        'fig/posix/__tests__/ln-test.ts',
        'fig/posix/__tests__/rm-test.ts',
        'fig/posix/__tests__/touch-test.ts',
        'fig/posix/chmod.ts',
        'fig/posix/chown.ts',
        'fig/posix/cp.ts',
        'fig/posix/id.ts',
        'fig/posix/ln.ts',
        'fig/posix/mkdir.ts',
        'fig/posix/mv.ts',
        'fig/posix/rm.ts',
        'fig/posix/touch.ts',
        'fig/prompt.ts',
        'fig/readAspect.ts',
        'fig/readConfig.ts',
        'fig/regExpFromString.ts',
        'fig/run.ts',
        'fig/status.ts',
        'fig/stringify.ts',
        'fig/template.ts',
        'fig/test.ts',
        'fig/test/harness.ts',
        'fig/types.d.ts',
        'fig/types/JSONValue.ts',
        'helpers.ts',
        'install',
        'package.json',
        'support/hooks/post-receive',
        'support/hooks/pre-push',
        'support/tinted-builder.rb',
        'support/typegen/Builder.ts',
        'support/typegen/SCHEMAS.ts',
        'support/typegen/index.ts',
        'tsconfig.json',
        'variables.ts',
        'vendor/fonts/source-code-pro/LICENSE.md',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-Black.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-BlackIt.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-Bold.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-BoldIt.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-ExtraLight.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-ExtraLightIt.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-It.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-Light.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-LightIt.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-Medium.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-MediumIt.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-Regular.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-Semibold.otf',
        'vendor/fonts/source-code-pro/OTF/SourceCodePro-SemiboldIt.otf',
        'vendor/fonts/source-code-pro/README.md',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-Black.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-BlackIt.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-Bold.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-BoldIt.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-ExtraLight.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-ExtraLightIt.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-It.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-Light.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-LightIt.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-Medium.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-MediumIt.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-Regular.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-Semibold.ttf',
        'vendor/fonts/source-code-pro/TTF/SourceCodePro-SemiboldIt.ttf',
        'vendor/fonts/source-code-pro/VF/SourceCodeVF-Italic.otf',
        'vendor/fonts/source-code-pro/VF/SourceCodeVF-Italic.ttf',
        'vendor/fonts/source-code-pro/VF/SourceCodeVF-Upright.otf',
        'vendor/fonts/source-code-pro/VF/SourceCodeVF-Upright.ttf',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-Black.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-BlackIt.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-Bold.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-BoldIt.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-ExtraLight.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-ExtraLightIt.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-It.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-Light.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-LightIt.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-Medium.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-MediumIt.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-Regular.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-Semibold.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/OTF/SourceCodePro-SemiboldIt.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-Black.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-BlackIt.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-Bold.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-BoldIt.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-ExtraLight.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-ExtraLightIt.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-It.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-Light.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-LightIt.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-Medium.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-MediumIt.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-Regular.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-Semibold.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/TTF/SourceCodePro-SemiboldIt.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/VF/SourceCodeVF-Italic.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/VF/SourceCodeVF-Italic.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF/VF/SourceCodeVF-Upright.otf.woff',
        'vendor/fonts/source-code-pro/WOFF/VF/SourceCodeVF-Upright.ttf.woff',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-Black.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-BlackIt.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-Bold.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-BoldIt.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-ExtraLight.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-ExtraLightIt.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-It.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-Light.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-LightIt.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-Medium.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-MediumIt.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-Regular.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-Semibold.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodePro-SemiboldIt.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodeVF-Italic.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/OTF/SourceCodeVF-Upright.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-Black.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-BlackIt.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-Bold.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-BoldIt.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-ExtraLight.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-ExtraLightIt.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-It.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-Light.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-LightIt.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-Medium.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-MediumIt.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-Regular.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-Semibold.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodePro-SemiboldIt.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodeVF-Italic.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/TTF/SourceCodeVF-Upright.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/VF/SourceCodeVF-Italic.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/VF/SourceCodeVF-Italic.ttf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/VF/SourceCodeVF-Upright.otf.woff2',
        'vendor/fonts/source-code-pro/WOFF2/VF/SourceCodeVF-Upright.ttf.woff2',
        'vendor/fonts/source-code-pro/package.json',
        'vendor/fonts/source-code-pro/source-code-pro.css',
        'vendor/fonts/source-code-pro/source-code-variable.css',
        'vendor/git-cipher/CHANGELOG.md',
        'vendor/git-cipher/LICENSE.md',
        'vendor/git-cipher/PROTOCOL.md',
        'vendor/git-cipher/README.md',
        'vendor/git-cipher/UPGRADING.md',
        'vendor/git-cipher/bin/git-cipher',
        'vendor/git-cipher/docs/common-options.md',
        'vendor/git-cipher/docs/git-cipher-add.md',
        'vendor/git-cipher/docs/git-cipher-clean.md',
        'vendor/git-cipher/docs/git-cipher-demo.md',
        'vendor/git-cipher/docs/git-cipher-diff.md',
        'vendor/git-cipher/docs/git-cipher-help.md',
        'vendor/git-cipher/docs/git-cipher-hook.md',
        'vendor/git-cipher/docs/git-cipher-init.md',
        'vendor/git-cipher/docs/git-cipher-is-encrypted.md',
        'vendor/git-cipher/docs/git-cipher-lock.md',
        'vendor/git-cipher/docs/git-cipher-log.md',
        'vendor/git-cipher/docs/git-cipher-ls.md',
        'vendor/git-cipher/docs/git-cipher-merge.md',
        'vendor/git-cipher/docs/git-cipher-show.md',
        'vendor/git-cipher/docs/git-cipher-smudge.md',
        'vendor/git-cipher/docs/git-cipher-textconv.md',
        'vendor/git-cipher/docs/git-cipher-unlock.md',
        'vendor/git-cipher/docs/git-wrapper.md',
        'vendor/git-cipher/examples/empty-file',
        'vendor/git-cipher/examples/fifteen-bytes',
        'vendor/git-cipher/examples/file',
        'vendor/git-cipher/examples/single-byte',
        'vendor/git-cipher/examples/spaces in name',
        'vendor/git-cipher/package.json',
        'vendor/git-cipher/src/Config.mts',
        'vendor/git-cipher/src/ExitStatus.mts',
        'vendor/git-cipher/src/Scanner.mts',
        'vendor/git-cipher/src/Unicode.mts',
        'vendor/git-cipher/src/assert.mts',
        'vendor/git-cipher/src/clean.mts',
        'vendor/git-cipher/src/commands/add.mts',
        'vendor/git-cipher/src/commands/clean.mts',
        'vendor/git-cipher/src/commands/demo.mts',
        'vendor/git-cipher/src/commands/diff.mts',
        'vendor/git-cipher/src/commands/help.mts',
        'vendor/git-cipher/src/commands/hook.mts',
        'vendor/git-cipher/src/commands/init.mts',
        'vendor/git-cipher/src/commands/is-encrypted.mts',
        'vendor/git-cipher/src/commands/lock.mts',
        'vendor/git-cipher/src/commands/log.mts',
        'vendor/git-cipher/src/commands/ls.mts',
        'vendor/git-cipher/src/commands/merge.mts',
        'vendor/git-cipher/src/commands/show.mts',
        'vendor/git-cipher/src/commands/smudge.mts',
        'vendor/git-cipher/src/commands/textconv.mts',
        'vendor/git-cipher/src/commands/unlock.mts',
        'vendor/git-cipher/src/commonOptions.mts',
        'vendor/git-cipher/src/crypto.mts',
        'vendor/git-cipher/src/dedent.mts',
        'vendor/git-cipher/src/git.mts',
        'vendor/git-cipher/src/gpg.mts',
        'vendor/git-cipher/src/hex.mts',
      })
    end)

    it('sorts a shorter string before a longer one that shares the same prefix', function()
      -- Regression test: `cmp_alpha()` was doing sketchy unsigned subtraction.
      local matcher = get_matcher({ 'foobar', 'foo', 'foobarb', 'foob' })
      expect(matcher.match('')).to_equal({ 'foo', 'foob', 'foobar', 'foobarb' })
    end)

    describe('the `ignore_spaces` option', function()
      local paths = { 'path_no_space', 'path with/space' }

      it('ignores the space character by default', function()
        local matcher = get_matcher(paths)
        expect(matcher.match('path space')).to_equal(paths)
      end)

      context('when `ignore_spaces` is `true`', function()
        it('ignores the space character', function()
          local matcher = get_matcher(paths, { ignore_spaces = true })
          expect(matcher.match('path space')).to_equal(paths)
        end)

        -- Regression test: `ignore_spaces` was undoing case conversion.
        it('does not undo case conversion', function()
          local matcher = get_matcher({ 'foobar' }, {
            ignore_case = true,
            ignore_spaces = true,
            smart_case = false,
          })
          expect(matcher.match('FOO BAR')).to_equal({ 'foobar' })
        end)
      end)

      context('when `ignore_spaces` is `false`', function()
        it('considers the space character to match a literal space', function()
          local matcher = get_matcher(paths, { ignore_spaces = false })
          expect(matcher.match('path space')).to_equal({ 'path with/space' })
        end)
      end)
    end)
  end)
end)
