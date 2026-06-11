class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :resumes,     dependent: :destroy
  has_many :folders,     dependent: :destroy
  has_many :jobs,        dependent: :destroy
  has_many :attachments, dependent: :destroy

  def over_token_limit?
    tokens_used >= token_limit
  end

  def token_usage_pct
    return 0 if token_limit.zero?
    [(tokens_used.to_f / token_limit * 100).round, 100].min
  end
end
