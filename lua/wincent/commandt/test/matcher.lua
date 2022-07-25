-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

describe('matcher.c', function()
  local lib = require('wincent.commandt.private.lib')

  local get_matcher = function(paths, options)
    options = options or {}
    local scanner = lib.scanner_new_copy(paths)
    local matcher = lib.commandt_matcher_new(scanner, options)
    return {
      match = function(query)
        local results = lib.commandt_matcher_run(matcher, query)
        local strings = {}
        for k = 0, results.count - 1 do
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

    it('performs case-insensitive matching', function()
      local matcher = get_matcher({ 'Foo' })
      expect(matcher.match('f')).to_equal({ 'Foo' })
    end)

    it('performs case-sensitive matching when configured to do so', function()
      local matcher = get_matcher({ 'Foo' }, { ignore_case = false })
      expect(matcher.match('b')).to_equal({})
      expect(matcher.match('f')).to_equal({})
      expect(matcher.match('F')).to_equal({ 'Foo' })
    end)

    it('performs smart-case matching when configured to do so', function()
      local matcher = get_matcher({ 'Foo' }, { smart_case = true })
      expect(matcher.match('b')).to_equal({})
      expect(matcher.match('f')).to_equal({ 'Foo' })
      expect(matcher.match('F')).to_equal({ 'Foo' })
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

    it('correctly computes non-recursive match score', function()
      -- Non-recursive match was incorrectly inflating some scores.
      -- Related: https://github.com/wincent/command-t/issues/209
      local matcher = get_matcher({
        'app/assets/components/App/index.jsx',
        'app/assets/components/PrivacyPage/index.jsx',
        'app/views/api/docs/pagination/_index.md',
      }, { recurse = false })

      -- You might want the second match here to come first, but in the
      -- non-recursive case we greedily match the "app" in "app", the "a" in
      -- "assets", the "p" in "components", and the first "p" in "App". This
      -- doesn't score as favorably as matching the "app" in "app", the "ap" in
      -- "api", and the "p" in "pagination".
      expect(matcher.match('appappind')).to_equal({
        'app/views/api/docs/pagination/_index.md',
        'app/assets/components/App/index.jsx',
        'app/assets/components/PrivacyPage/index.jsx',
      })
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
