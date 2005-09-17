require File.dirname(__FILE__) + '/../test_helper'

class EntryTest < Test::Unit::TestCase
  fixtures :entries

  def setup
    @entry = Entry.find(1)
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Entry,  @entry
  end
end
