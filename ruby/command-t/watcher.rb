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
    def initialize(par, dir)
      @parent = par
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
        Process.kill('USR1', @parent)
      end
    end
  end
end

if $0 == __FILE__
  if (par = ARGV.first.to_i) > 0 && (dir = ARGV[1])
    CommandT::WatchDelegate.new(par, dir).watch
  else
    puts "Bad invocation"
  end
end
