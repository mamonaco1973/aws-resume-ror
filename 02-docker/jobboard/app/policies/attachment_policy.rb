class AttachmentPolicy < ApplicationPolicy
  def create?  = record.job.user_id == user.id
  def destroy? = record.user_id == user.id
end
