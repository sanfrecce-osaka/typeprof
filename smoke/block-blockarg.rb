def log1(x); end
def log2(x); end
def log3(x); end

def f(&blk)
  log3(
    blk.call do |x|
      log1(x)
      :b
    end
  )
  :d
end

f do |&blk|
  log2(blk.call(:a))
  :c
end

__END__
# Classes
class Object
  def log1 : (:a) -> nil
  def log2 : (:b) -> nil
  def log3 : (:c) -> nil
  def f : { { (:a) -> :b } -> :c } -> :d
end
