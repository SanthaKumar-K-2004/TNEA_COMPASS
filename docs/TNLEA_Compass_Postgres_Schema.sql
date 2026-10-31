-- TNLEA Compass starter schema (PostgreSQL)
-- Review and apply via migrations in non-production first.
-- Important: source data is versioned; missing observations are NULL, never zero.

CREATE SCHEMA IF NOT EXISTS tnlea;
SET search_path TO tnlea, public;

CREATE TABLE IF NOT EXISTS source_documents (
    source_document_id BIGSERIAL PRIMARY KEY,
    publisher TEXT NOT NULL,
    document_title TEXT NOT NULL,
    document_type TEXT NOT NULL,
    admission_year SMALLINT,
    academic_year TEXT,
    canonical_url TEXT NOT NULL,
    retrieved_url TEXT,
    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sha256 CHAR(64),
    content_type TEXT,
    byte_size BIGINT CHECK (byte_size IS NULL OR byte_size >= 0),
    page_count INTEGER CHECK (page_count IS NULL OR page_count > 0),
    storage_uri TEXT,
    authority_tier TEXT NOT NULL DEFAULT 'primary'
        CHECK (authority_tier IN ('primary','official_institution','secondary','community','unknown')),
    verification_status TEXT NOT NULL DEFAULT 'source_found_not_validated'
        CHECK (verification_status IN ('not_found','source_found_not_downloaded','source_found_not_validated','downloaded_not_validated','partially_extracted','parsed_needs_review','verified','conflicting_sources','rejected')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_source_documents_year ON source_documents(admission_year, document_type);
CREATE INDEX IF NOT EXISTS idx_source_documents_status ON source_documents(verification_status);
CREATE INDEX IF NOT EXISTS idx_source_documents_sha256 ON source_documents(sha256);

CREATE TABLE IF NOT EXISTS ingestion_runs (
    ingestion_run_id BIGSERIAL PRIMARY KEY,
    source_document_id BIGINT NOT NULL REFERENCES source_documents(source_document_id),
    parser_name TEXT NOT NULL,
    parser_version TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    run_status TEXT NOT NULL DEFAULT 'started'
        CHECK (run_status IN ('started','succeeded','succeeded_with_warnings','failed','review_required','published')),
    extracted_rows INTEGER NOT NULL DEFAULT 0 CHECK (extracted_rows >= 0),
    accepted_rows INTEGER NOT NULL DEFAULT 0 CHECK (accepted_rows >= 0),
    rejected_rows INTEGER NOT NULL DEFAULT 0 CHECK (rejected_rows >= 0),
    error_summary TEXT,
    code_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ingestion_runs_source ON ingestion_runs(source_document_id, started_at DESC);

CREATE TABLE IF NOT EXISTS source_evidence (
    source_evidence_id BIGSERIAL PRIMARY KEY,
    source_document_id BIGINT NOT NULL REFERENCES source_documents(source_document_id),
    ingestion_run_id BIGINT REFERENCES ingestion_runs(ingestion_run_id),
    page_number INTEGER CHECK (page_number IS NULL OR page_number > 0),
    table_reference TEXT,
    row_reference TEXT,
    raw_excerpt TEXT,
    raw_record JSONB,
    row_sha256 CHAR(64),
    extraction_method TEXT NOT NULL DEFAULT 'text_extraction',
    verification_status TEXT NOT NULL DEFAULT 'pending_review'
        CHECK (verification_status IN ('pending_review','auto_checked','human_verified','rejected','conflict')),
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_source_evidence_document_page ON source_evidence(source_document_id, page_number);
CREATE INDEX IF NOT EXISTS idx_source_evidence_hash ON source_evidence(row_sha256);
CREATE INDEX IF NOT EXISTS idx_source_evidence_json ON source_evidence USING GIN(raw_record);

CREATE TABLE IF NOT EXISTS staging_records (
    staging_record_id BIGSERIAL PRIMARY KEY,
    ingestion_run_id BIGINT NOT NULL REFERENCES ingestion_runs(ingestion_run_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    record_type TEXT NOT NULL,
    raw_record JSONB NOT NULL,
    normalized_candidate JSONB,
    validation_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (validation_status IN ('pending','passed','warning','rejected','published')),
    validation_errors JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_staging_records_run_status ON staging_records(ingestion_run_id, validation_status);

CREATE TABLE IF NOT EXISTS colleges (
    college_id BIGSERIAL PRIMARY KEY,
    preferred_name TEXT NOT NULL,
    district TEXT,
    address TEXT,
    official_website TEXT,
    official_email TEXT,
    official_phone TEXT,
    institution_type TEXT,
    ownership_type TEXT,
    affiliating_university TEXT,
    profile_status TEXT NOT NULL DEFAULT 'partial'
        CHECK (profile_status IN ('verified','partial','needs_review','inactive','merged_pending_review')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_colleges_preferred_name ON colleges USING GIN(to_tsvector('simple', preferred_name));
CREATE INDEX IF NOT EXISTS idx_colleges_district ON colleges(district);

-- Codes may collide or change across sources/years; do not impose a global UNIQUE on college_code.
CREATE TABLE IF NOT EXISTS college_code_assignments (
    college_code_assignment_id BIGSERIAL PRIMARY KEY,
    college_id BIGINT NOT NULL REFERENCES colleges(college_id),
    college_code TEXT NOT NULL,
    valid_from_admission_year SMALLINT,
    valid_to_admission_year SMALLINT,
    source_document_id BIGINT REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    mapping_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (mapping_status IN ('verified','candidate','collision','rejected','needs_review')),
    raw_college_name TEXT,
    notes TEXT,
    CHECK (valid_to_admission_year IS NULL OR valid_from_admission_year IS NULL OR valid_to_admission_year >= valid_from_admission_year)
);
CREATE INDEX IF NOT EXISTS idx_college_code_assignments_code ON college_code_assignments(college_code, valid_from_admission_year);
CREATE INDEX IF NOT EXISTS idx_college_code_assignments_college ON college_code_assignments(college_id);

CREATE TABLE IF NOT EXISTS branches (
    branch_id BIGSERIAL PRIMARY KEY,
    canonical_name TEXT NOT NULL,
    broad_family TEXT,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_branches_name ON branches USING GIN(to_tsvector('simple', canonical_name));

CREATE TABLE IF NOT EXISTS branch_aliases (
    branch_alias_id BIGSERIAL PRIMARY KEY,
    branch_id BIGINT NOT NULL REFERENCES branches(branch_id),
    branch_code TEXT NOT NULL,
    alias_name TEXT,
    valid_from_admission_year SMALLINT,
    valid_to_admission_year SMALLINT,
    source_document_id BIGINT REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    mapping_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (mapping_status IN ('verified','candidate','needs_review','rejected'))
);
CREATE INDEX IF NOT EXISTS idx_branch_aliases_code_year ON branch_aliases(branch_code, valid_from_admission_year);

CREATE TABLE IF NOT EXISTS college_branch_offerings (
    offering_id BIGSERIAL PRIMARY KEY,
    college_id BIGINT NOT NULL REFERENCES colleges(college_id),
    branch_id BIGINT NOT NULL REFERENCES branches(branch_id),
    admission_year SMALLINT NOT NULL,
    participation_status TEXT NOT NULL DEFAULT 'historical_evidence_only'
        CHECK (participation_status IN ('officially_listed','historical_evidence_only','not_offered','unverified','conflict')),
    approved_intake INTEGER CHECK (approved_intake IS NULL OR approved_intake >= 0),
    lateral_entry_seats INTEGER CHECK (lateral_entry_seats IS NULL OR lateral_entry_seats >= 0),
    counselling_seats INTEGER CHECK (counselling_seats IS NULL OR counselling_seats >= 0),
    vacancy_round TEXT,
    vacancy_count INTEGER CHECK (vacancy_count IS NULL OR vacancy_count >= 0),
    source_document_id BIGINT REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    verification_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (verification_status IN ('verified','partial','needs_review','unavailable','conflict')),
    notes TEXT,
    UNIQUE (college_id, branch_id, admission_year)
);
CREATE INDEX IF NOT EXISTS idx_offerings_year ON college_branch_offerings(admission_year, participation_status);
CREATE INDEX IF NOT EXISTS idx_offerings_branch ON college_branch_offerings(branch_id, admission_year);

CREATE TABLE IF NOT EXISTS cutoff_observations (
    cutoff_observation_id BIGSERIAL PRIMARY KEY,
    offering_id BIGINT NOT NULL REFERENCES college_branch_offerings(offering_id),
    admission_year SMALLINT NOT NULL,
    category_code TEXT NOT NULL,
    metric_type TEXT NOT NULL CHECK (metric_type IN ('published_min_marks','published_max_marks','opening_rank','closing_rank')),
    metric_value NUMERIC(12,5),
    unit TEXT NOT NULL DEFAULT 'as_published',
    counselling_phase TEXT NOT NULL DEFAULT 'not_stated',
    raw_value TEXT NOT NULL,
    null_reason TEXT CHECK (null_reason IS NULL OR null_reason IN ('published_dash','blank_cell','parse_failure','not_published','unknown')),
    source_document_id BIGINT NOT NULL REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT NOT NULL REFERENCES source_evidence(source_evidence_id),
    verification_status TEXT NOT NULL DEFAULT 'pending_review'
        CHECK (verification_status IN ('verified_source_row','auto_checked','pending_review','rejected','conflict')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK ((metric_value IS NULL) OR
           (metric_type IN ('published_min_marks','published_max_marks') AND metric_value >= 0 AND metric_value <= 100) OR
           (metric_type IN ('opening_rank','closing_rank') AND metric_value > 0)),
    CHECK ((metric_value IS NOT NULL AND null_reason IS NULL) OR (metric_value IS NULL AND null_reason IS NOT NULL)),
    UNIQUE (offering_id, admission_year, category_code, metric_type, counselling_phase, source_document_id)
);
CREATE INDEX IF NOT EXISTS idx_cutoff_lookup ON cutoff_observations(admission_year, category_code, metric_type, offering_id);
CREATE INDEX IF NOT EXISTS idx_cutoff_source ON cutoff_observations(source_document_id, verification_status);

CREATE TABLE IF NOT EXISTS fee_schedules (
    fee_schedule_id BIGSERIAL PRIMARY KEY,
    college_id BIGINT NOT NULL REFERENCES colleges(college_id),
    branch_id BIGINT REFERENCES branches(branch_id),
    programme TEXT,
    academic_year TEXT,
    valid_from DATE,
    valid_to DATE,
    quota_or_admission_route TEXT,
    student_type TEXT,
    source_document_id BIGINT NOT NULL REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    verification_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (verification_status IN ('verified','partial','needs_review','expired','conflict')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fee_components (
    fee_component_id BIGSERIAL PRIMARY KEY,
    fee_schedule_id BIGINT NOT NULL REFERENCES fee_schedules(fee_schedule_id) ON DELETE CASCADE,
    component_name TEXT NOT NULL,
    component_type TEXT NOT NULL,
    amount_inr NUMERIC(12,2) NOT NULL CHECK (amount_inr >= 0),
    cadence TEXT NOT NULL CHECK (cadence IN ('one_time','annual','semester','monthly','per_exam','per_credit','deposit','unknown')),
    mandatory BOOLEAN,
    refundable BOOLEAN,
    applies_to_year SMALLINT,
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fee_schedules_college_year ON fee_schedules(college_id, academic_year);
CREATE INDEX IF NOT EXISTS idx_fee_components_schedule ON fee_components(fee_schedule_id);

CREATE TABLE IF NOT EXISTS placement_reports (
    placement_report_id BIGSERIAL PRIMARY KEY,
    college_id BIGINT NOT NULL REFERENCES colleges(college_id),
    branch_id BIGINT REFERENCES branches(branch_id),
    graduating_cohort TEXT,
    reporting_year SMALLINT,
    programme_scope TEXT NOT NULL CHECK (programme_scope IN ('institution_overall','engineering_overall','programme','branch','department','unknown')),
    population_definition TEXT,
    source_document_id BIGINT NOT NULL REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    reporting_period TEXT,
    verification_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (verification_status IN ('verified','partial','needs_review','conflict','expired')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS placement_metrics (
    placement_metric_id BIGSERIAL PRIMARY KEY,
    placement_report_id BIGINT NOT NULL REFERENCES placement_reports(placement_report_id) ON DELETE CASCADE,
    metric_key TEXT NOT NULL CHECK (metric_key IN ('eligible_students','placed_students','placement_rate_percent','median_ctc','average_ctc','highest_ctc','internship_count','higher_studies_count','recruiter_count','other')),
    numeric_value NUMERIC(16,4) NOT NULL CHECK (numeric_value >= 0),
    unit TEXT NOT NULL,
    currency TEXT,
    denominator_value NUMERIC(16,4) CHECK (denominator_value IS NULL OR denominator_value >= 0),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_placement_report_scope ON placement_reports(college_id, reporting_year, branch_id);
CREATE INDEX IF NOT EXISTS idx_placement_metrics_key ON placement_metrics(placement_report_id, metric_key);

CREATE TABLE IF NOT EXISTS ranking_observations (
    ranking_observation_id BIGSERIAL PRIMARY KEY,
    college_id BIGINT NOT NULL REFERENCES colleges(college_id),
    publisher TEXT NOT NULL,
    ranking_system TEXT NOT NULL,
    ranking_category TEXT NOT NULL,
    ranking_year SMALLINT NOT NULL,
    rank_value INTEGER CHECK (rank_value IS NULL OR rank_value > 0),
    score_value NUMERIC(12,5) CHECK (score_value IS NULL OR score_value >= 0),
    source_document_id BIGINT NOT NULL REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    verification_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (verification_status IN ('verified','partial','needs_review','conflict')),
    methodology_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rankings_lookup ON ranking_observations(ranking_system, ranking_category, ranking_year, college_id);

CREATE TABLE IF NOT EXISTS college_attributes (
    college_attribute_id BIGSERIAL PRIMARY KEY,
    college_id BIGINT NOT NULL REFERENCES colleges(college_id),
    attribute_key TEXT NOT NULL,
    attribute_value JSONB NOT NULL,
    valid_from DATE,
    valid_to DATE,
    source_document_id BIGINT REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    verification_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (verification_status IN ('verified','partial','needs_review','conflict','expired')),
    notes TEXT,
    CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);
CREATE INDEX IF NOT EXISTS idx_college_attributes_key ON college_attributes(college_id, attribute_key);
CREATE INDEX IF NOT EXISTS idx_college_attributes_value ON college_attributes USING GIN(attribute_value);

CREATE TABLE IF NOT EXISTS career_pathways (
    career_pathway_id BIGSERIAL PRIMARY KEY,
    branch_id BIGINT REFERENCES branches(branch_id),
    pathway_name TEXT NOT NULL,
    role_family TEXT,
    skills JSONB NOT NULL DEFAULT '[]'::jsonb,
    project_ideas JSONB NOT NULL DEFAULT '[]'::jsonb,
    pathway_scope TEXT NOT NULL DEFAULT 'general_guidance'
        CHECK (pathway_scope IN ('general_guidance','college_specific_outcome')),
    source_document_id BIGINT REFERENCES source_documents(source_document_id),
    source_evidence_id BIGINT REFERENCES source_evidence(source_evidence_id),
    verification_status TEXT NOT NULL DEFAULT 'needs_review'
        CHECK (verification_status IN ('verified','secondary','needs_review','conflict')),
    disclaimer TEXT NOT NULL DEFAULT 'Career pathways are guidance, not a guarantee of placement or salary.'
);

CREATE TABLE IF NOT EXISTS model_versions (
    model_version_id BIGSERIAL PRIMARY KEY,
    model_name TEXT NOT NULL,
    model_type TEXT NOT NULL,
    code_version TEXT NOT NULL,
    source_data_fingerprint CHAR(64),
    feature_schema_version TEXT NOT NULL,
    training_start_year SMALLINT,
    training_end_year SMALLINT,
    trained_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    model_parameters JSONB NOT NULL DEFAULT '{}'::jsonb,
    evaluation_summary JSONB NOT NULL DEFAULT '{}'::jsonb,
    release_status TEXT NOT NULL DEFAULT 'experimental'
        CHECK (release_status IN ('experimental','approved','published','retired','rejected')),
    limitations TEXT
);

CREATE TABLE IF NOT EXISTS backtest_results (
    backtest_result_id BIGSERIAL PRIMARY KEY,
    model_version_id BIGINT NOT NULL REFERENCES model_versions(model_version_id),
    forecast_target_year SMALLINT NOT NULL,
    training_end_year SMALLINT NOT NULL,
    segment_type TEXT NOT NULL DEFAULT 'all',
    segment_key TEXT,
    observations_count INTEGER NOT NULL CHECK (observations_count >= 0),
    mae NUMERIC(12,5),
    median_absolute_error NUMERIC(12,5),
    rmse NUMERIC(12,5),
    mean_error_bias NUMERIC(12,5),
    interval_coverage NUMERIC(6,5) CHECK (interval_coverage IS NULL OR (interval_coverage >= 0 AND interval_coverage <= 1)),
    average_interval_width NUMERIC(12,5),
    baseline_mae NUMERIC(12,5),
    baseline_improvement NUMERIC(12,5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_backtest_model_year ON backtest_results(model_version_id, forecast_target_year);

CREATE TABLE IF NOT EXISTS predictions (
    prediction_id BIGSERIAL PRIMARY KEY,
    model_version_id BIGINT NOT NULL REFERENCES model_versions(model_version_id),
    offering_id BIGINT NOT NULL REFERENCES college_branch_offerings(offering_id),
    target_admission_year SMALLINT NOT NULL,
    category_code TEXT NOT NULL,
    metric_type TEXT NOT NULL CHECK (metric_type IN ('published_min_marks','published_max_marks')),
    point_estimate NUMERIC(12,5) NOT NULL CHECK (point_estimate >= 0 AND point_estimate <= 100),
    lower_bound NUMERIC(12,5),
    upper_bound NUMERIC(12,5),
    nominal_interval_level NUMERIC(5,4),
    verified_comparable_years SMALLINT NOT NULL DEFAULT 0 CHECK (verified_comparable_years >= 0),
    data_coverage_label TEXT NOT NULL CHECK (data_coverage_label IN ('low','medium','high','insufficient')),
    model_reliability_label TEXT NOT NULL CHECK (model_reliability_label IN ('low','medium','high','experimental','not_evaluated')),
    method_description TEXT NOT NULL,
    explanation JSONB NOT NULL DEFAULT '{}'::jsonb,
    prediction_status TEXT NOT NULL DEFAULT 'experimental'
        CHECK (prediction_status IN ('experimental','published','withdrawn','replaced')),
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (lower_bound IS NULL OR (lower_bound >= 0 AND lower_bound <= point_estimate)),
    CHECK (upper_bound IS NULL OR (upper_bound >= point_estimate AND upper_bound <= 100)),
    CHECK (lower_bound IS NULL OR upper_bound IS NULL OR lower_bound <= upper_bound)
);
CREATE INDEX IF NOT EXISTS idx_predictions_target ON predictions(target_admission_year, category_code, metric_type, prediction_status);
CREATE INDEX IF NOT EXISTS idx_predictions_offering ON predictions(offering_id, target_admission_year);

CREATE TABLE IF NOT EXISTS data_quality_issues (
    data_quality_issue_id BIGSERIAL PRIMARY KEY,
    ingestion_run_id BIGINT REFERENCES ingestion_runs(ingestion_run_id),
    source_document_id BIGINT REFERENCES source_documents(source_document_id),
    entity_type TEXT NOT NULL,
    entity_key TEXT,
    field_name TEXT,
    rule_code TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('critical','high','medium','low','info')),
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open','in_review','resolved','accepted_with_note','false_positive')),
    expected_value TEXT,
    observed_value TEXT,
    evidence JSONB NOT NULL DEFAULT '{}'::jsonb,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    reviewer TEXT,
    resolution_note TEXT
);
CREATE INDEX IF NOT EXISTS idx_quality_issues_status ON data_quality_issues(status, severity, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_quality_issues_entity ON data_quality_issues(entity_type, entity_key);

-- Views should be created after production queries are agreed. Avoid computing a "chance of admission"
-- from historical cutoff distance until that probability has been empirically calibrated and validated.
