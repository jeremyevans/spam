# The filters added to this controller will be run for all controllers in the application.
# Likewise will all the methods added be available for all controllers.
class ApplicationController < ActionController::Base
  before_filter :get_navigation_accounts
  
  private
    def demo_mode?
      DEMO_MODE == true
    end

    def get_navigation_accounts
      session[:user_id] = 1 if demo_mode?
      @navigation_accounts = Account.unhidden_register_accounts(session[:user_id]) if session[:user_id]
    end
    
    def require_login
      unless session[:user_id]
        flash[:notice] = 'You need to login'
        redirect_to(:controller=>'login', :action=>'index')
      end
    end
end
