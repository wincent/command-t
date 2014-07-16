# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'command-t/scanner/file_scanner'

describe CommandT::FileScanner do
  before do
    dir = File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures')
    @scanner = CommandT::FileScanner.new(dir)
  end

  describe 'flush method' do
    it 'forces a rescan on next call to paths method' do
      expect { @scanner.flush }.
        to change { @scanner.instance_variable_get('@paths').object_id }
    end
  end
end
