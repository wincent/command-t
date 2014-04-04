#!/usr/bin/env ruby

require 'rubygems'
require 'fsevent'

module CommandT
  class Watcher < ::FSEvent
    def initialize(watcher, dir)
      super()
      self.watch_directories([dir])
      @watcher = watcher
    end

    def on_change(dirs)
      @watcher.dirs_changed(dirs)
    end
  end

  class WatchDelegate
    def initialize(dir)
      @watcher = Watcher.new(self, dir)
      @dir = dir
    end

    def watch_parent
      Thread.new do
        if parent_dead?
          puts "Parent dead"
          exit(0)
        else
          sleep(1)
        end
      end
    end

    def parent_dead?
      Process.ppid == 1
    end

    def watch
      watch_parent
      @watcher.start
    end

    def dirs_changed(dirs)
      unless parent_dead?
        Process.kill('USR1', Process.ppid)
      end
    end
  end
end

if $0 == __FILE__
  if dir = ARGV.first
    CommandT::WatchDelegate.new(dir).watch
  else
    puts "Bad invocation"
    exit 2
  end
end
