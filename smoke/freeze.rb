def foo
  [1].freeze
end

foo

__END__
# Classes
class Object
  def foo : -> [Integer]
end
