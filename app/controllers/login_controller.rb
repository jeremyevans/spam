class LoginController < ApplicationController
  filter_parameter_logging :password
  def login
    flash[:notice] = unless session[:user_id] = User.login_user_id(params[:username], params[:password])
      'Incorrect username or password'
    else
      'You have been logged in'
    end
    redirect_to(:action=>'index')
  end
  
  def logout
    reset_session
    flash[:notice] = 'You have been logged out'
    redirect_to(:action=>'index')
  end
end
