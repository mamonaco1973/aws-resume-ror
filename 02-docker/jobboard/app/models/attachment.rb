class Attachment < ApplicationRecord
  belongs_to :job
  belongs_to :user
  has_one_attached :file

  validates :filename, presence: true

  validate :file_content_type
  validate :file_size_limit

  private

  def file_content_type
    return unless file.attached?
    allowed = %w[
      application/pdf application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      text/plain image/jpeg image/png
    ]
    unless file.content_type.in?(allowed)
      errors.add(:file, "must be a PDF, Word document, text file, or image")
    end
  end

  def file_size_limit
    return unless file.attached?
    # 10 MB cap matches the original app's per-file limit
    if file.byte_size > 10.megabytes
      errors.add(:file, "must be under 10 MB")
    end
  end
end
