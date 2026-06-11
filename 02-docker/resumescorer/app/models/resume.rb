class Resume < ApplicationRecord
  belongs_to :user
  has_many   :jobs, dependent: :nullify

  validates :name,         presence: true
  validates :content_text, presence: true, length: { minimum: 50 }
end
