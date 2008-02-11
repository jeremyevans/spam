ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require File.dirname(__FILE__) + '/../vendor/plugins/scaffolding_extensions/test/scaffolding_extensions_test'

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  # Test that getting all display actions for the scaffold returns success
  def scaffold_test(model, options = {})
    klass = @controller.class
    methods = options[:only] ? klass.scaffold_normalize_options(options[:only]) : ScaffoldingExtensions::DEFAULT_METHODS
    methods -= klass.scaffold_normalize_options(options[:except]) if options[:except]
    methods.each do |action|
      assert_nothing_raised("Error requesting scaffolded action #{action} for model #{model.name}") do
        get "#{action}_#{model.scaffold_name}", {}, {:user_id=>1}
      end
      assert_response :success, "Response for scaffolded action #{action} for model #{model.name} not :success"
    end
  end
end
