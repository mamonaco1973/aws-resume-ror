class AttachmentsController < ApplicationController
  before_action :set_job

  def create
    @attachment = @job.attachments.build(user: current_user,
                                         filename: attachment_file.original_filename)
    authorize @attachment
    @attachment.file.attach(attachment_file)

    if @attachment.save
      redirect_to @job, notice: "Attachment added."
    else
      redirect_to @job, alert: @attachment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @attachment = @job.attachments.find(params[:id])
    authorize @attachment
    @attachment.destroy
    redirect_to @job, notice: "Attachment removed."
  end

  private

  def set_job
    @job = current_user.jobs.find(params[:job_id])
  end

  def attachment_file
    params.require(:attachment).require(:file)
  end
end
