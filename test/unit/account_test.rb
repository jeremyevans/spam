require File.dirname(__FILE__) + '/../test_helper'

class AccountTest < Test::Unit::TestCase
  fixtures :accounts

  def setup
    @account = Account.find(1)
  end

  # Replace this with your real tests.
  def test_truth
    assert_kind_of Account,  @account
  end
end
