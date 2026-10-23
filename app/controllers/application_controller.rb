class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def ensure_authenticated_and_active!
    if session[:user_id].present?
      current_user = User.find_by(id: session[:user_id])
      if current_user.nil? || current_user.status == 'blocked'
        session[:user_id] = nil
        redirect_to login_path, alert: 'Your account has been blocked or deleted.'
      else
        current_user.update(last_seen: Time.current)
      end
    else
      redirect_to login_path, alert: 'Please login first.'
    end
  end
end