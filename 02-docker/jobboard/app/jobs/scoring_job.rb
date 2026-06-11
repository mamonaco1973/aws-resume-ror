require "net/http"
require "json"

# ==============================================================================
# ScoringJob
# Sidekiq background job that scores a resume against a job posting using
# AWS Bedrock (Claude Haiku). Runs two Bedrock calls:
#   1. Extract job title, company, and normalized job text from the source
#   2. Score the resume text against the extracted job description (0-100)
# Token usage is accumulated on the user record for display and rate limiting.
# ==============================================================================
class ScoringJob < ApplicationJob
  queue_as :default

  MAX_SOURCE_CHARS  = 120_000
  MIN_JOB_CHARS     = 100
  BEDROCK_MODEL_ENV = "BEDROCK_MODEL_ID"

  def perform(job_id)
    @job  = Job.find_by(id: job_id)
    return unless @job

    @user   = @job.user
    @resume = @job.resume

    return mark_error("Token limit reached. This job was not scored.") \
      if @user.over_token_limit?

    @job.update!(status: "scoring", status_message: "Started job scoring")

    resume_text = @resume.content_text.to_s.strip
    return mark_error("Resume has no text content — re-upload the file.") \
      if resume_text.blank?

    job_text = extract_job_description
    return if @job.reload.status == "error"

    return mark_error("Token limit reached after extraction.") \
      if @user.reload.over_token_limit?

    scored = score_resume(resume_text, job_text)
    return if @job.reload.status == "error"

    @job.update!(
      job_description_text: job_text,
      score:                Integer(scored["score"]),
      analysis:             scored["summary"].to_s.strip,
      status:               "scored",
      status_message:       ""
    )
  rescue => e
    mark_error(e.message.to_s.truncate(500)) if @job
  end

  private

  # ------------------------------------------------------------------------------
  # Job description extraction
  # For URL jobs: fetch HTML, strip noise, call Bedrock to extract fields.
  # For raw_text: call Bedrock directly on the supplied text.
  # ------------------------------------------------------------------------------

  def extract_job_description
    raw = if @job.source_type == "url"
            html = fetch_url(@job.url)
            return nil unless html
            extract_visible_text(html)
          else
            @job.raw_text.to_s
          end

    if raw.blank?
      mark_error("No text could be extracted from the source")
      return nil
    end

    extracted = call_bedrock(extraction_prompt(raw), max_tokens: 1000)
    return nil if extracted.nil?

    parsed = JSON.parse(strip_fences(extracted))

    title   = parsed["job_title"].to_s.strip
    company = parsed["company_name"].to_s.strip
    text    = parsed["job_text"].to_s.strip

    if text.length < MIN_JOB_CHARS
      mark_error("Extracted job description is too short to score")
      return nil
    end

    # Update title and company immediately so they appear in the UI
    # while the slower scoring call is still in progress.
    @job.update!(title: title, company: company)

    text
  rescue JSON::ParserError
    mark_error("Bedrock returned invalid JSON during extraction")
    nil
  end

  # ------------------------------------------------------------------------------
  # Resume scoring
  # Returns the parsed JSON hash with "score" (integer) and "summary" (string).
  # ------------------------------------------------------------------------------

  def score_resume(resume_text, job_text)
    raw = call_bedrock(scoring_prompt(resume_text, job_text), max_tokens: 4000)
    return nil if raw.nil?

    parsed = JSON.parse(strip_fences(raw))
    score  = parsed["score"]

    # Bedrock occasionally returns score as a string
    score = Integer(score.to_s.strip) if score.is_a?(String)

    unless score.is_a?(Integer) && score.between?(0, 100)
      mark_error("Bedrock returned an invalid score value")
      return nil
    end

    if parsed["summary"].to_s.strip.blank?
      mark_error("Bedrock did not return analysis text")
      return nil
    end

    parsed
  rescue JSON::ParserError
    mark_error("Bedrock returned invalid JSON during scoring")
    nil
  end

  # ------------------------------------------------------------------------------
  # Bedrock call wrapper
  # Accumulates token usage on the user record after each successful call.
  # ------------------------------------------------------------------------------

  def call_bedrock(prompt, max_tokens:)
    client = Aws::BedrockRuntime::Client.new(region: ENV.fetch("AWS_REGION", "us-east-1"))
    model  = ENV.fetch(BEDROCK_MODEL_ENV, "us.anthropic.claude-haiku-4-5-20251001-v1:0")

    body = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens:        max_tokens,
      temperature:       0,
      messages: [{
        role:    "user",
        content: [{ type: "text", text: prompt }]
      }]
    }.to_json

    response = client.invoke_model(
      model_id:     model,
      body:         body,
      content_type: "application/json",
      accept:       "application/json"
    )

    payload = JSON.parse(response.body.read)
    usage   = payload.fetch("usage", {})

    accumulate_tokens(
      usage.fetch("input_tokens", 0).to_i,
      usage.fetch("output_tokens", 0).to_i
    )

    payload.dig("content", 0, "text")
  rescue Aws::BedrockRuntime::Errors::ServiceError => e
    mark_error("Bedrock error: #{e.message.truncate(200)}")
    nil
  end

  def accumulate_tokens(input, output)
    total = input + output
    return if total <= 0
    # Uses SQL ADD for atomicity — safe under concurrent scoring jobs
    @user.with_lock { @user.increment!(:tokens_used, total) }
  rescue => e
    Rails.logger.warn("ScoringJob: token accumulation failed: #{e.message}")
  end

  # ------------------------------------------------------------------------------
  # Prompts — match the extraction/scoring logic from the original Python worker
  # ------------------------------------------------------------------------------

  def extraction_prompt(source_text)
    <<~PROMPT.strip
      You are extracting structured data from a job posting.

      Return valid JSON only.

      Required JSON fields:
      - job_title
      - company_name
      - job_text

      Rules:
      - job_title: best extracted job title, or empty string if unknown
      - company_name: best extracted company name, or empty string if unknown
      - job_text: plain-text job description, maximum 3000 characters, include
        only role responsibilities and candidate requirements
      - Do not wrap the response in markdown
      - Do not include any explanation

      SOURCE TEXT:
      #{source_text.slice(0, MAX_SOURCE_CHARS)}
    PROMPT
  end

  def scoring_prompt(resume_text, job_text)
    <<~PROMPT.strip
      You are scoring a resume against a job description.

      Return valid JSON only.

      Required JSON fields:
      - score
      - summary

      Rules:
      - score: integer from 0 to 100
      - summary: plain-text analysis with exactly three labeled paragraphs in
        this order: "Overview:" (2-3 sentences explaining why the score is
        what it is), "Strengths:" (2-3 sentences on resume positives relative
        to the job), "Weaknesses:" (2-3 sentences on gaps or missing
        qualifications)
      - Do not wrap the response in markdown
      - Do not include any explanation outside the JSON

      RESUME:
      #{resume_text.slice(0, MAX_SOURCE_CHARS)}

      JOB DESCRIPTION:
      #{job_text.slice(0, MAX_SOURCE_CHARS)}
    PROMPT
  end

  # ------------------------------------------------------------------------------
  # URL fetching + HTML text extraction
  # ------------------------------------------------------------------------------

  def fetch_url(url)
    uri      = URI.parse(url)
    use_ssl  = uri.scheme == "https"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl,
                               read_timeout: 30, open_timeout: 10) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " \
                          "AppleWebKit/537.36 (KHTML, like Gecko) " \
                          "Chrome/122.0.0.0 Safari/537.36"
      http.request(req)
    end
    response.body.force_encoding("UTF-8").encode("UTF-8", invalid: :replace)
  rescue => e
    mark_error("Failed to fetch URL: #{e.message.truncate(200)}")
    nil
  end

  def extract_visible_text(html)
    require "nokogiri"
    doc = Nokogiri::HTML(html)

    # Remove elements that never contain useful job content
    doc.css("script, style, noscript, nav, footer, header, " \
            "svg, img, form, input, button, select, iframe").remove

    text = doc.text.gsub(/[ \t\f\v]+/, " ")
                   .gsub(/ *\n */, "\n")
                   .gsub(/\n{3,}/, "\n\n")
                   .strip

    # Include page title as context for extraction
    title = doc.at_css("title")&.text&.strip
    [title.present? ? "PAGE TITLE: #{title}" : nil, text].compact.join("\n\n")
  end

  # ------------------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------------------

  def strip_fences(text)
    text = text.strip
    return text unless text.start_with?("```")
    lines = text.lines
    lines.shift                        # remove opening fence
    lines.pop if lines.last&.strip == "```"
    lines.join.strip
  end

  def mark_error(message)
    @job&.update(status: "error", status_message: message.to_s.truncate(500))
  end
end
