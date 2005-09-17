require File.dirname(__FILE__) + '/../test_helper'

class EntityTest < Test::Unit::TestCase
  fixtures :entities

  def setup
    @entity = Entity.find(1)
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Entity,  @entity
  end
end
