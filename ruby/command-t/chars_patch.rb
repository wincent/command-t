
class String
  def chars_alias(&block)
    self.each(&block)
  end

  unless String.method_defined? :chars
    alias_method :chars, :chars_alias
  end
end
