# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'

describe CommandT::VIM do
  describe '.escape_for_single_quotes' do
    it 'turns doubles all single quotes' do
      input = %{it's ''something''}
      expected = %{it''s ''''something''''}
      expect(CommandT::VIM.escape_for_single_quotes(input)).to eq(expected)
    end
  end

  describe '.wildignore_to_regexp' do
    subject do
      Regexp.new(CommandT::VIM.wildignore_to_regexp(wildignore))
    end

    describe '"foo"' do
      let(:wildignore) { 'foo' }

      it 'matches the right strings' do
        expect(subject).to_not match('a.foo')
        expect(subject).to_not match('a/b.foo')
        expect(subject).to match('foo')
        expect(subject).to match('a/foo')
        expect(subject).to_not match('a/foo/b')
      end
    end

    describe '".foo"' do
      let(:wildignore) { '*.foo' }

      it 'matches the right strings' do
        expect(subject).to match('a.foo')
        expect(subject).to match('a/b.foo')
        expect(subject).to_not match('foo')
        expect(subject).to_not match('a/foo')
        expect(subject).to_not match('a/foo/b')
      end
    end

    describe '"*/foo/*"' do
      let(:wildignore) { '*/foo' }

      it 'matches the right strings' do
        expect(subject).to_not match('a.foo')
        expect(subject).to_not match('a/b.foo')
        expect(subject).to match('foo')
        expect(subject).to match('a/foo')
        expect(subject).to match('a/foo/b')
      end
    end

    describe '"*/foo/*"' do
      let(:wildignore) { '*/foo/*' }

      it 'matches the right strings' do
        expect(subject).to_not match('a.foo')
        expect(subject).to_not match('a/b.foo')
        expect(subject).to_not match('foo')
        expect(subject).to_not match('a/foo')
        expect(subject).to match('a/foo/b')
      end
    end

    describe 'multiple patterns' do
      let(:wildignore) { '*.foo,*/foo/*' }

      it 'matches the right strings' do
        expect(subject).to match('a.foo')
        expect(subject).to match('a/b.foo')
        expect(subject).to_not match('foo')
        expect(subject).to_not match('a/foo')
        expect(subject).to match('a/foo/b')
      end
    end
  end
end
