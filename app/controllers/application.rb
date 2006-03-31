# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base
  before_filter :get_navigation_accounts
  private
    def get_navigation_accounts
      @navigation_accounts = Account.unhidden_register_accounts
    end
end