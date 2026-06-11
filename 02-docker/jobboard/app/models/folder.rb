class Folder < ApplicationRecord
  belongs_to :user
  has_many   :jobs, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
end
