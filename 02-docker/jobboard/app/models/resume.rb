class Resume < ApplicationRecord
  belongs_to :user
  has_many   :jobs, dependent: :nullify
  has_one_attached :file

  validates :name, presence: true

  # Extract text from the attached file and persist it so scoring jobs
  # don't have to re-download the file on every invocation.
  def extract_and_store_text
    return unless file.attached?

    text = case file.content_type
           when "application/pdf" then extract_pdf_text
           else file.download.force_encoding("UTF-8")
           end

    update_column(:content_text, text.to_s.strip)
  end

  private

  def extract_pdf_text
    require "pdf-reader"
    io = StringIO.new(file.download)
    PDF::Reader.new(io).pages.map(&:text).join("\n")
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
    ""
  end
end
