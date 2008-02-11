require File.dirname(__FILE__) + '/../test_helper'
require 'update_controller'

# Re-raise errors caught by the controller.
class UpdateController; def rescue_action(e) raise e end; end

class UpdateControllerTest < Test::Unit::TestCase
  def setup
    @controller = UpdateController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  test_scaffold_all_models :only=>[Account, Entity, Entry]
end
