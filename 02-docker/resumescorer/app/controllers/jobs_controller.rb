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
    resume = current_user.resumes.find_by(id: params[:job][:resume_id])

    if resume.nil?
      redirect_to new_resume_path, alert: "Add a resume before scoring jobs."
      return
    end

    folder_id = params[:job][:folder_id].presence

    if params[:job][:source_type] == "linkedin_id"
      ids = params[:job][:linkedin_ids].to_s
                .lines.map { |l| l.strip.gsub(/\D/, "") }
                .reject(&:blank?)
                .first(10)

      if ids.empty?
        @job     = Job.new
        @resumes = current_user.resumes.order(:name)
        @folders = current_user.folders.order(:name)
        flash.now[:alert] = "Enter at least one LinkedIn job ID."
        return render :new, status: :unprocessable_entity
      end

      ids.each do |lid|
        job = current_user.jobs.create!(
          resume:      resume,
          folder_id:   folder_id,
          source_type: "url",
          url:         "https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/#{lid}"
        )
        ScoringJob.perform_later(job.id)
      end

      redirect_to dashboard_path,
        notice: "#{ids.size} LinkedIn #{"job".pluralize(ids.size)} submitted for scoring."
    else
      @job        = current_user.jobs.build(job_params)
      @job.resume = resume

      if @job.save
        ScoringJob.perform_later(@job.id)
        redirect_to @job, notice: "Job submitted — scoring will begin shortly."
      else
        @resumes = current_user.resumes.order(:name)
        @folders = current_user.folders.order(:name)
        render :new, status: :unprocessable_entity
      end
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
      :source_type, :url, :raw_text, :folder_id, :notes
    )
  end
end
