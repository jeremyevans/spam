class ApplicationController < ActionController::Base
  before_filter :get_navigation_accounts
  NOT_FOUNDS = [AbstractController::ActionNotFound, ActionController::UnknownController, ActionController::UnknownAction, ActionController::RoutingError]
  NOT_FOUNDS.each{|e| rescue_from e, :with=>:render_404}
  
  def process(*a)
    super
  rescue *NOT_FOUNDS
    process_action("render_404")
  end

  def render_404
    render(:text=>File.read("#{Rails.root}/public/404.html"), :status=>404)
  end

  private

  def demo_mode?
    DEMO_MODE == true
  end

  def get_navigation_accounts
    session[:user_id] = 1 if demo_mode?
    @navigation_accounts = userAccount.unhidden.register_accounts if session[:user_id]
  end
    
  def require_login
    unless session[:user_id]
      flash[:notice] = 'You need to login'
      redirect_to(:controller=>'login', :action=>'index')
    end
  end

  def userAccount
    Account.user(session[:user_id])
  end 

  def userEntity
    Entity.user(session[:user_id])
  end 

  def userEntry
    Entry.user(session[:user_id])
  end
end
