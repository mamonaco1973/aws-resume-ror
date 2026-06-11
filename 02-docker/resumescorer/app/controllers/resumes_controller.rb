class ResumesController < ApplicationController
  def index
    skip_authorization
    @resumes = current_user.resumes.order(created_at: :desc)
  end

  def show
    @resume = current_user.resumes.find(params[:id])
    authorize @resume
  end

  def new
    authorize Resume
    @resume = Resume.new
  end

  def create
    authorize Resume
    @resume = current_user.resumes.build(resume_params)
    if @resume.save
      redirect_to resumes_path, notice: "Resume saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @resume = current_user.resumes.find(params[:id])
    authorize @resume
    @resume.destroy
    redirect_to resumes_path, notice: "Resume deleted."
  end

  private

  def resume_params
    params.require(:resume).permit(:name, :content_text)
  end
end
