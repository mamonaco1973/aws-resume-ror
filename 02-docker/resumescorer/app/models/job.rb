class Job < ApplicationRecord
  belongs_to :user
  belongs_to :resume
  belongs_to :folder, optional: true
  has_many   :attachments, dependent: :destroy

  STATUSES = %w[pending scoring scored error].freeze

  validates :source_type, inclusion: { in: %w[url raw_text] }
  validates :url,      presence: true, if: -> { source_type == "url" }
  validates :raw_text, presence: true, if: -> { source_type == "raw_text" }

  scope :recent,     -> { order(created_at: :desc) }
  scope :scored,     -> { where(status: "scored") }
  scope :pending,    -> { where(status: %w[pending scoring]) }
  scope :in_folder,  ->(fid) { where(folder_id: fid) if fid.present? }
  scope :by_keyword, ->(q) {
    where("title ILIKE ? OR company ILIKE ?", "%#{q}%", "%#{q}%") if q.present?
  }

  def scored?
    status == "scored"
  end

  def processing?
    status.in?(%w[pending scoring])
  end

  def errored?
    status == "error"
  end

  def score_color
    return "gray" unless scored? && score
    if score >= 75 then "green"
    elsif score >= 50 then "yellow"
    else "red"
    end
  end
end
