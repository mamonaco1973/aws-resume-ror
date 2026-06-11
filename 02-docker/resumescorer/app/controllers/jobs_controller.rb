class JobsController < ApplicationController
  before_action :set_job, only: [:show, :update, :destroy]

  def index
    redirect_to dashboard_path
  end

  def show
    authorize @job
    @attachments = @job.attachments.order(created_at: :desc)
  end

  def new
    authorize Job
    @job     = Job.new
    @resumes = current_user.resumes.order(:name)
    @folders = current_user.folders.order(:name)
    redirect_to new_resume_path, alert: "Upload a resume before scoring jobs." \
      if @resumes.empty?
  end

  def create
    authorize Job
    @job = current_user.jobs.build(job_params)
    @job.resume = current_user.resumes.find(params[:job][:resume_id])

    # LinkedIn job ID — convert to a guest API URL so ScoringJob needs no
    # special case. The guest endpoint returns job HTML without requiring login.
    if @job.source_type == "linkedin_id" && params[:job][:linkedin_id].present?
      lid = params[:job][:linkedin_id].to_s.strip.gsub(/\D/, "")
      @job.url         = "https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/#{lid}"
      @job.source_type = "url"
    end

    if @job.save
      ScoringJob.perform_later(@job.id)
      redirect_to @job, notice: "Job submitted — scoring will begin shortly."
    else
      @resumes = current_user.resumes.order(:name)
      @folders = current_user.folders.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @job
    @job.update!(notes: params[:job][:notes])
    redirect_to @job, notice: "Notes saved."
  end

  def destroy
    authorize @job
    @job.destroy
    redirect_to dashboard_path, notice: "Job removed."
  end

  private

  def set_job
    @job = current_user.jobs.find(params[:id])
  end

  def job_params
    params.require(:job).permit(
      :source_type, :url, :raw_text, :folder_id, :notes, :linkedin_id
    )
  end
end
