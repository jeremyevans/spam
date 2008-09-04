module ValuesSummingTo
  # Return the sum of the values.
  def sum(values)
    values.inject(0){|x,y| x+=y}
  end
  
  # Yield all subsets of the array to the block.
  def subsets(array, skip = 0, &block)
    yield(array)
    (array.length-1).downto(skip){|i| subsets(array[0...i] + array[i+1..-1], i, &block)}
  end

  # Yield all subsets of values that sum to want, using the meet in the
  # middle algorithm (O(n * 2^(n/2)).
  def all_values_summing_to(values, want, max_seconds=nil)
    i = false
    v1, v2 = values.partition{i=!i}
    sums = {}
    start_time = Time.now if max_seconds
    subsets(v1) do |comb|
      return if max_seconds and Time.now - start_time > max_seconds
      sums[sum(comb)] = comb
    end
    subsets(v2) do |comb|
      return if max_seconds and Time.now - start_time > max_seconds
      if comb2 = sums[want - sum(comb)]
        yield comb2 + comb
      end
    end
    nil
  end

  # Return the first subset of values that sums to want, or nil, if no subset
  # sums to want.
  def find_values_summing_to(values, want, max_seconds = nil)
    # Immediately return if the value are looking for is an element of the array
    values.each{|value| return [value] if value == want}
    all_values_summing_to(values.reject{|value| value == 0}, want, max_seconds){|comb| return comb}
  end
end
