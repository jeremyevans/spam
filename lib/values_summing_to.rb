module ValuesSummingTo
  def sum(values)
    values.inject(0){|x,y| x+=y}
  end

  def combinations(array, skip = 0, &block)
    return if (false == yield(array))
    l = array.length
    (l-1).downto(skip){|i| combinations(array[0...i] + array[i+1..-1], i, &block)}
  end

  def all_values_summing_to(values, want, always_block=nil, &block)
    combinations(values.reject{|value| value == 0}) do |comb|
      always_block.call if always_block
      if sum(comb) == want
        yield comb
        next
      end
      pos, neg = [], []
      comb.each{|value| ((value > 0) ? pos : neg) << value}
      tp, tn = sum(pos), sum(neg)
      if tp == want
        yield pos
        next
      end
      if tn == want
        yield neg
        next
      end
      unless (want > 0 && tp < want) || (want < 0 && tn >= want)
        comb.delete_if{|value| want > 0 ? (value + tn > want) && tp -= value : (value + tp < want) && tn -= value}
      end
    end
    nil
  end

  def find_values_summing_to(values, want, max_seconds = nil)
    values.each{|value| return [value] if value == want}
    start_time = Time.now if max_seconds
    all_values_summing_to(values, want, Proc.new{return nil if max_seconds && Time.now - start_time > max_seconds}){|comb| return comb}
  end
end
