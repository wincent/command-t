module CommandT
  class Stub
    @@load_error = ['command-t.vim could not load the necessary modules',
                    'Please double-check the installation instructions',
                    'For more information type:  :help command-t']

    def show
      warn *@@load_error
    end

    def flush
      warn *@@load_error
    end

  private

    def warn *msg
      VIM::command 'echohl WarningMsg'
      msg.each { |m| VIM::command "echo '#{m}'" }
      VIM::command 'echohl none'
    end
  end # class Stub
end # module CommandT
