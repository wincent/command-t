
class String
  def chars_hacked(&block)
    self.split(//).to_a
  end

  if String.method_defined? :chars
    alias_method :chars, :chars_hacked
  end
end
