# Zeitwerk stub — not used in the resume scoring app.
class ApplicationNotificationJob < ApplicationJob
  queue_as :default

  def perform(*); end
end
