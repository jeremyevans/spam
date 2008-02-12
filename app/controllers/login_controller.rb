class LoginController < ApplicationController
  filter_parameter_logging :password
  before_filter :require_login, :except=>['index', 'login']
  
  def update_password
    return redirect_to(:action=>'index') if demo_mode?
    page = 'change_password'
    flash[:notice] = if params[:password] && params[:password2]
      if params[:password].length < 6
        "Password too short, use at least 6 characters, preferably 10 or more."
      elsif params[:password] != params[:password2]
        "Passwords don't match, please try again."
      else
        user = User.find(session[:user_id])
        user.password = params[:password]
        if user.save
          page = 'index'
          'Password updated.'
        else
          "Can't update account."
        end
      end
    else
      "No password provided, so can't change it."
    end
    redirect_to(:action=>page)
  end
  
  def login
    return redirect_to(:action=>'index') if demo_mode?
    flash[:notice] = unless session[:user_id] = User.login_user_id(params[:username], params[:password])
      'Incorrect username or password.'
    else
      'You have been logged in.'
    end
    redirect_to(:action=>'index')
  end
  
  def logout
    reset_session
    flash[:notice] = 'You have been logged out.'
    redirect_to(:action=>'index')
  end
end
