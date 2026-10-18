class SessionsController < ApplicationController
  def new
    render :login
  end

  def create
    user = User.find_by(email: params[:email])
    if user && user.authenticate(params[:password])
      if user.status == 'blocked'
        flash.now[:alert] = 'Your account is blocked.'
        render :login, status: :unprocessable_entity
      else
        session[:user_id] = user.id
        user.update(last_seen: Time.current)
        redirect_to users_path, notice: 'Logged in successfully.'
      end
    else
      flash.now[:alert] = 'Invalid email or password.'
      render :login, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: 'Logged out successfully.'
  end
end
