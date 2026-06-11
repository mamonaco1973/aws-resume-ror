class DashboardController < ApplicationController
  def index
    skip_authorization
    @jobs    = current_user.jobs
                 .includes(:resume, :folder)
                 .recent
                 .in_folder(params[:folder_id])
                 .by_keyword(params[:q])
    @folders = current_user.folders.order(:name)
    @resumes = current_user.resumes.order(:name)
  end

  def usage
    skip_authorization
    @user = current_user
  end
end
