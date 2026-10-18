class UsersController < ApplicationController
  before_action :authenticate_user!, except: [:new, :create]
  before_action :check_user_status

  def index
    @users = User.order(last_seen: :desc)
  end

  def new
    @user = User.new
    render :register
  end

  def create
    @user = User.new(user_params)
    @user.status = 'active'
    @user.last_seen = Time.current

    if @user.save
      session[:user_id] = @user.id
      flash[:notice] = "Registration successful! Welcome, #{@user.full_name}."
      redirect_to users_path
    else
      flash.now[:alert] = @user.errors.full_messages.join(', ')
      render :register, status: :unprocessable_entity
    end
  end

  def block_selected
    User.where(id: params[:user_ids]).update_all(status: 'blocked')
    check_if_current_user_affected(params[:user_ids])
  end

  def unblock_selected
    User.where(id: params[:user_ids]).update_all(status: 'active')
    redirect_to users_path, notice: "Selected users unblocked."
  end

def delete_selected
    if params[:user_ids].present?
      current_user_deleted = params[:user_ids].include?(session[:user_id].to_s)

      User.where(id: params[:user_ids]).destroy_all

      if current_user_deleted
        session[:user_id] = nil
        redirect_to login_path, notice: 'Your account was deleted successfully.'
      else
        redirect_to users_path, notice: 'Selected users deleted successfully.'
      end
    else
      redirect_to users_path, alert: 'No users selected for deletion.'
    end
  end

  private

  def user_params
    params.require(:user).permit(:full_name, :email, :job_position, :password, :password_confirmation)
  end

  def authenticate_user!
    redirect_to login_path, alert: 'Please login first.' unless session[:user_id]
  end

  def check_user_status
    if session[:user_id]
      current_user = User.find_by(id: session[:user_id])
      if current_user.nil? || current_user.status == 'blocked'
        session[:user_id] = nil
        redirect_to login_path, alert: 'Your account has been blocked or deleted.'
      else
        current_user.update(last_seen: Time.current)
      end
    end
  end

  def check_if_current_user_affected(user_ids, deleted: false)
    if user_ids&.include?(session[:user_id].to_s)
      session[:user_id] = nil
      redirect_to login_path, alert: deleted ? 'You deleted your own account.' : 'You blocked your own account.'
    else
      redirect_to users_path, notice: "Action completed successfully."
    end
  end
end
