require File.dirname(__FILE__) + '/../test_helper'
require 'qif_controller'

# Re-raise errors caught by the controller.
class QifController; def rescue_action(e) raise e end; end

class QifControllerTest < Test::Unit::TestCase
  def setup
    @controller = QifController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
