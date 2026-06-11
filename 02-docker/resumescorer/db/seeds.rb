# Seeds are idempotent — safe to re-run on every container start.
# find_or_create_by! ensures no duplicates across redeploys.

puts "NOTE: Seeding demo user..."

demo = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.password              = "password123"
  u.password_confirmation = "password123"
  u.token_limit           = 100_000
  u.tokens_used           = 0
end

puts "NOTE: Seeding demo resumes..."

unless demo.resumes.exists?
  r1 = demo.resumes.create!(name: "Software Engineer Resume")
  r1.update!(content_text: <<~TEXT.strip)
    Jane Smith
    Software Engineer | jane@example.com | github.com/janesmith

    EXPERIENCE
    Senior Software Engineer - Acme Corp (2020-present)
    - Led migration of monolithic Rails app to microservices, reducing p99
      latency by 40%
    - Designed and shipped real-time notification system serving 500K users
    - Mentored 3 junior engineers and conducted weekly code reviews

    Software Engineer - StartupCo (2017-2020)
    - Built REST API with Ruby on Rails and PostgreSQL, serving 1M req/day
    - Implemented CI/CD pipeline with GitHub Actions and Docker

    SKILLS
    Ruby, Rails, Python, Go, PostgreSQL, Redis, AWS (ECS, Lambda, S3, RDS),
    Terraform, Docker, Kubernetes

    EDUCATION
    B.S. Computer Science - State University (2017)
  TEXT

  r2 = demo.resumes.create!(name: "Data Engineer Resume")
  r2.update!(content_text: <<~TEXT.strip)
    Jane Smith
    Data Engineer | jane@example.com

    EXPERIENCE
    Data Engineer - BigData Inc (2021-present)
    - Built ETL pipelines processing 10TB/day using Apache Spark and Airflow
    - Designed Snowflake data warehouse schema for analytics team
    - Reduced pipeline failure rate from 15% to 0.5%

    Junior Data Analyst - Corp Analytics (2018-2021)
    - Created Tableau dashboards consumed by C-suite weekly
    - Automated Excel reporting with Python, saving 20 hours/week

    SKILLS
    Python, SQL, Spark, Airflow, Snowflake, dbt, AWS Glue, Redshift, Tableau

    EDUCATION
    B.S. Statistics - State University (2018)
  TEXT
end

puts "NOTE: Seeding demo folders..."

folder = demo.folders.find_or_create_by!(name: "Tech Companies")
demo.folders.find_or_create_by!(name: "Startups")

puts "NOTE: Seeding demo jobs..."

unless demo.jobs.exists?
  demo.jobs.create!(
    resume:               demo.resumes.first,
    folder:               folder,
    title:                "Senior Rails Engineer",
    company:              "Acme Corp",
    source_type:          "raw_text",
    raw_text:             "Seeking an experienced Rails engineer with 5+ years experience.",
    job_description_text: "Senior Rails Engineer at Acme Corp. 5+ years Rails, AWS, PostgreSQL.",
    score:                82,
    analysis:             "Overview: Strong match. Candidate's Rails background aligns well with the role.\n\nStrengths: Direct Rails experience, AWS familiarity, and team leadership are all directly relevant.\n\nWeaknesses: No Kubernetes experience listed; the role lists it as preferred.",
    status:               "scored"
  )

  demo.jobs.create!(
    resume:               demo.resumes.first,
    folder:               folder,
    title:                "Backend Engineer",
    company:              "TechCorp",
    source_type:          "raw_text",
    raw_text:             "Looking for a backend engineer with Go and PostgreSQL experience.",
    job_description_text: "Backend Engineer at TechCorp. Go and PostgreSQL required, 3+ years.",
    score:                61,
    analysis:             "Overview: Partial match. Candidate has strong database skills but limited Go experience.\n\nStrengths: PostgreSQL experience and API design background are directly applicable.\n\nWeaknesses: Go is not a primary skill; the role requires 3+ years of Go experience.",
    status:               "scored"
  )
end

puts "NOTE: Seeding complete."
