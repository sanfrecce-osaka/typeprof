def foo(n)
  n = n || 42
  n
end

foo(1)
foo(nil)

__END__
# Classes
class Object
  def foo : (Integer?) -> Integer
end
