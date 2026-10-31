# TNLEA Compass — Implementation Blueprint

**Version:** 1.0  
**Prepared:** 29 October 2026  
**Deployment preference:** Low-cost, incremental launch  
**Product languages:** Tamil + English  
**First priority:** Historical cutoff coverage and trustworthy forecasting  
**Scope:** Data pipeline, database, ML evaluation, APIs, frontend, career/placement intelligence, operations

---

## 1. Executive decision

Build TNLEA Compass as a **data platform first**, with a student-facing Next.js application, a Python/FastAPI backend, PostgreSQL as the source of truth, and a separate Python ingestion/modeling pipeline. Keep the first deployment a modular monolith. Do not begin with microservices, Kubernetes, an LLM agent framework, or a large vector database.

The system must always distinguish:

1. **Published fact** — explicitly present in a traceable source.
2. **Normalized fact** — parsed and checked from the source, with raw evidence retained.
3. **Derived metric** — calculated from published records and a documented formula.
4. **Forecast** — a model estimate with backtest results and uncertainty.
5. **Unknown / unavailable** — not found or not verified; never represented as zero.

The product must not imply that a historical cutoff guarantees a seat. In the current project, “MAX” and “MIN” in the official cutoff PDFs refer to published cutoff marks/averages, not opening and closing ranks. Preserve that distinction end-to-end.

## 2. Current-project baseline and coverage audit

The existing project is a useful starting point, not a finished statewide data warehouse. The current research files indicate:

- Full extracted TNLEA cutoff records are present for admission years **2024 and 2025**.
- The project report records 14,980 cutoff-category records for 2024 and 15,736 for 2025 in the full extract, totaling **30,716**.
- The project has two cutoff CSV variants with different sizes: `TNLEA_Historical_Cutoffs.csv` has **16,317** rows while `TNLEA_Historical_Cutoffs_FULL.csv` has **30,716** rows. Their lineage/filters must be reconciled before production use or model training.
- The full extract has 427 college-code profiles, 4,388 college/branch/year evidence rows, and 1,846 matched college/branch/category minimum-mark series with 2024 and 2025 values, according to the current project report.
- An official online source for 2023 maximum/minimum cutoff marks has been identified, but the project’s local `originals/tnlea/2023/cutoff_previous_year_2023.pdf` is only 715 bytes and is not a valid complete source artifact. Re-download, checksum and validate the online source before ingesting it.
- The 2022 source has not been identified/validated in the current audit.
- The official 2026 portal currently exposes a Round 1 vacancy-position page, and the 2026 portal links to the previous-year 2025 cutoff table. A complete final 2026 cutoff dataset has not been verified in this project.
- The current project contains only four fee records and does not have statewide, verified fee/hostel or placement coverage.
- A current projection CSV exists, but its method is explicitly a two-point straight-line scenario, not a trained or validated ML model.

### Five-year target: 2022–2026

| Admission year | Current evidence status | Required action | Can it train/validate the production model now? |
|---|---|---|---|
| 2022 | **Gap — not recovered/verified** | Search official portal, government archives, institutional archives and reputable archived copies; preserve source provenance. | No |
| 2023 | **Official online source identified; project copy invalid/incomplete** | Re-download, confirm PDF signature/page count/hash, extract all rows, compare sampled rows with the rendered PDF, review parse errors. | Not yet |
| 2024 | **Imported into current project** | Reconcile row-count variant; validate extraction and category coverage; record page/row lineage. | Yes, after reconciliation |
| 2025 | **Imported into current project** | Reconcile row-count variant; validate extraction and category coverage; record page/row lineage. | Yes, after reconciliation |
| 2026 | **Final cutoff history not verified** | Search for published final 2026 records after admission; do not substitute Round 1 vacancies for final cutoffs. | No, until a comparable final outcome source is verified |

**Coverage rule:** The five-year goal is a collection target, not a claim of present completeness. The system must show a per-year evidence badge and list missing years on every historical coverage view.

### Immediate audit blocker

Before forecasting begins, explain the 16,317-row and 30,716-row variants. Compare keys, null values, source files, extraction scripts and filtering logic. The full extract’s expected grain appears to be one observation for each combination of admission year × college × branch × category × measure (published MAX/MIN). Write a reproducible reconciliation report showing row counts by year, category, college, branch, measure, null reason and source page. Do not discard either variant until the difference is understood.

## 3. Technology stack

### Frontend

- **Next.js + React + TypeScript** for routing, server rendering where useful, student-facing SEO pages and API consumption.
- **Tailwind CSS + shadcn/ui** for accessible, consistent components.
- **Motion for React** for restrained transitions, number-count effects and page changes. Respect `prefers-reduced-motion`; animation must never delay or obscure the data.
- **Apache ECharts** for cutoff trends, predicted bands, placement trends, salary comparisons and fee/outcome plots.
- **next-intl** (or an equivalent maintained i18n library) for English/Tamil content, localized labels, numerals and date/currency formatting.
- **Zod** for frontend request validation where useful; generated TypeScript API types should come from OpenAPI to reduce drift.

### Backend and database

- **Python + FastAPI** for the public API and administrative endpoints.
- **Pydantic** for request/response contracts.
- **SQLAlchemy 2.x + Alembic** for database access and versioned schema migrations.
- **PostgreSQL** as the authoritative structured data store. Use regular indexes and materialized views only after profiling; do not add pgvector until there is a real retrieval use case.
- **Redis is not required initially.** Add a small cache only when measured request volume justifies it.

### Ingestion and machine learning

- **Python** for reproducible extraction and quality checks.
- **PyMuPDF** and/or `pdfplumber` for PDF text and table extraction; use OCR only for pages that lack usable text layers, and manually review important OCR-derived values.
- **pandas / NumPy** for tabular normalization, profiling and feature preparation.
- **scikit-learn** for transparent baselines, regularized regression and evaluation. Consider CatBoost/LightGBM only after enough comparable, validated training data exists.
- **pytest** for parser, data-contract and API tests; add `pandera` or equivalent dataframe schema checks if useful.
- **MLflow is optional later** for model/version tracking. Start with database model-run records and checked-in evaluation scripts if this is enough.

### Low-cost hosting plan

- **Frontend:** Vercel Hobby or a suitable static/edge host, depending on the Next.js rendering needs and current provider limits.
- **PostgreSQL:** Neon or Supabase managed PostgreSQL on an entry/free plan while the dataset and workload are small.
- **FastAPI:** one low-cost managed Python service. Avoid a sleeping/free service for critical admission windows unless its cold-start behavior is acceptable.
- **Raw-source archive:** Cloudflare R2 or an equivalent low-cost object store; maintain source checksums and local/backup copies.
- **Scheduled ingestion:** GitHub Actions or a small scheduled job initially. Respect source terms, rate limits and robots/access rules; do not bypass access controls.
- **Monitoring/backups:** application error monitoring, database backups, exportable snapshots and an uptime check.

Provider pricing and free-tier limits change. Confirm current terms before deployment. Keep the architecture portable: standard PostgreSQL, Python API, Dockerfile, environment-based configuration and migrations.

## 4. Logical architecture

```text
Official TNLEA / government / institution sources
                |
                v
      Source registry + downloader
                |
                v
  Immutable raw files + SHA-256 checksums
                |
                v
   Parser / extraction / normalization
                |
                v
 Staging tables + raw source-row evidence
                |
                v
 Validation, duplicate detection, review queue
                |
                v
             PostgreSQL
       /         |          \
      v          v           v
 Cutoff API   Fees/placements  College and branch directory
      |
      v
 Baseline + ML forecasting + backtesting
      |
      v
 Versioned predictions with intervals & caveats
      |
      v
 Next.js student application (Tamil + English)
```

Keep the pipeline stages independently rerunnable. Re-running a parser should not silently create duplicate curated records. A new source version must create a new import run and evidence trail.

## 5. Database design

Use a normalized relational schema. The companion `TNLEA_Compass_Postgres_Schema.sql` provides a starting migration for the core entities. Production migrations should be split into smaller files and reviewed before application.

### Core entities

| Table / entity | Purpose and key design choices |
|---|---|
| `source_documents` | Publisher, title, admission year, canonical URL, retrieval time, SHA-256, raw file location, document type, authority tier and verification status. A changed PDF at the same URL must produce a new source version. |
| `source_evidence` | Source page, table/row reference, raw excerpt, row hash, extraction method and reviewer status. Curated values must point to evidence. |
| `ingestion_runs` | Parser version, source document, start/end, status, rows extracted/accepted/rejected and error log. |
| `staging_records` | Raw JSON/text from a source before normalization; retain parse issues and original strings. |
| `colleges` | Stable internal college ID and curated display name. Do not assume the text name or code is globally stable forever. |
| `college_code_assignments` | College code by effective admission year/source. Retain collisions instead of arbitrarily merging them; unresolved duplicate codes go to review. |
| `branches` / `branch_aliases` | Canonical branch taxonomy plus official codes and name variants by year/source. A code dictionary is a label source, not proof that a college offered the branch in that year. |
| `college_branch_offerings` | College × branch × admission year, with verified/observed status, approved intake, lateral-entry seats and round vacancies if actually published. Missing seat figures remain NULL. |
| `cutoff_observations` | One observation per published measure: `published_min_marks`, `published_max_marks`, and only if a source explicitly provides them, `opening_rank`/`closing_rank`. Preserve community/category, admission year, phase/round, source and raw representation. |
| `fee_schedules` / `fee_components` | Academic year/validity, programme, quota/student type, component, amount, cadence, mandatory/refundable flags and source evidence. Never mix one-time deposits, annual fees and monthly mess charges into one unlabelled total. |
| `placement_reports` / `placement_metrics` | Institution/programme/branch/cohort, population definition, reporting year, metric, value, unit, eligible/placed counts and source. Keep median, average and highest salary separate. |
| `ranking_observations` | Publisher, methodology/category, rank year, rank value, score and source. Different systems remain separate instead of being collapsed into one official rank. |
| `college_attributes` | Verified facilities, hostel, transport, accreditation and other time-bound attributes with source and validity dates. |
| `model_versions` | Model name, code/data version, training window, feature set hash, training date, parameters and evaluation summary. |
| `predictions` | Target admission year, college/branch/category, metric, point estimate, interval, model/version, supporting year count, confidence label, generated timestamp and status. |
| `backtest_results` | Training cutoff year, holdout year, metric values, cohort size and slice. Enables actual-versus-predicted reporting. |
| `data_quality_issues` | Rule, severity, entity/key, evidence, detected time, disposition and reviewer notes. |
| `career_pathways` | Carefully sourced branch-to-role/skill pathways, with source quality and a clear distinction between general career guidance and college-specific placement outcomes. |

### Required grain and key rules

- Cutoff grain: **admission year × college identity/code assignment × branch × category × published measure × round/phase when stated × source version**.
- Fee grain: institution/programme/quota/student type × academic year/validity × fee component × cadence × source.
- Placement grain: institution/programme/branch (if explicitly reported) × graduating cohort/reporting year × population definition × metric.
- Ranking grain: institution × publisher × ranking category/methodology × year.
- Do not join placement outcomes by college name alone. Use reviewed institution identity mappings and keep a confidence/status flag if identity matching is unresolved.
- Do not coerce missing or dash values to zero.
- Do not convert cutoff marks into ranks, or compare different admission processes as though their scales were interchangeable.

### Student privacy

The admission finder can work without an account. Calculate user inputs in the request and avoid retaining names, phone numbers, community details or score profiles by default. If accounts/saved lists are added, collect the minimum data, disclose retention, protect access and add deletion controls. The public analytics pipeline must not expose personal student records.

## 6. Data-ingestion pipeline

### Step 1 — Source discovery and registry

Maintain a `source_documents` register with authority levels:

1. Official TNLEA/Tamil Nadu Directorate of Technical Education documents for lateral-entry cutoffs, rules, seat/vacancy notices and official lists.
2. Relevant government or official institution documents for fees, approvals, placement disclosures and facilities.
3. Official NIRF pages/reports for ranking-specific data and the disclosed methodology.
4. Secondary sources only for discovery or corroboration; flag as secondary and never silently overwrite primary evidence.

Each source record must include publisher, title, cycle/year, URL, captured date, checksum, exact data fields supported and caveats.

### Step 2 — Immutable download

- Fetch the source to raw storage.
- Validate HTTP status, content type, file signature, page count and minimum plausible size.
- Calculate SHA-256 and preserve the original bytes.
- Record fetch time, effective URL, status and any access errors.
- If a URL changes content, store a new version rather than overwrite the old file.

### Step 3 — Parse and stage

- Extract text/tables from PDFs or structured CSV/XLSX/HTML.
- Preserve original strings, dashes, blank cells and category headers.
- Record source page and row index where possible.
- Add an extraction method and parser version.
- Send low-confidence/OCR-derived rows into manual review.

### Step 4 — Normalize

- Normalize Unicode, spaces, punctuation and casing for join candidates without deleting raw names.
- Use college code + admission year + source evidence first; use name/address similarity only as a candidate match.
- Maintain branch code aliases by year. Never infer yearly branch availability from a branch dictionary alone.
- Map community labels to a canonical taxonomy while preserving source category labels.
- Normalize marks as numeric values only when safely parsed; dashes become NULL plus `null_reason='published_dash'`.
- Store rank values only when a rank is published by the official source. A column named `rank` that is always blank must not be treated as actual rank data.

### Step 5 — Quality gates

Every ingestion must check:

- Duplicate composite keys and exact duplicate rows.
- Required-field completeness and null/dash rates by year/category/source.
- Numeric cutoff mark bounds (0–100 when the source scale is marks/average), invalid ranks, impossible negative fees, currency/cadence consistency and dates.
- `MIN > MAX` anomalies when both values exist, followed by source-PDF spot checks.
- College-code collision rate, unmapped branches, orphan college/branch foreign keys and joins that unexpectedly multiply row counts.
- Expected year and category coverage, page counts, extraction exceptions and changes from the previous source version.
- For placements, whether placed count exceeds eligible count and whether placement rate has a known denominator and scope.
- For fees, whether year, quota, cadence and refundable-deposit semantics are stated or explicitly unknown.

A pipeline may auto-publish only rows that pass hard validation. Soft anomalies enter review. Preserve rejected rows and their reasons.

### Step 6 — Human review and publishing

Review at least a sample of each cutoff year/category/source page plus all high-risk anomalies. Compare rendered source pages to extracted values. Once approved, promote staging rows transactionally into curated tables and mark the import run as published. Keep a review queue and audit log.

### Step 7 — Refresh strategy

- Admission cycle: check official TNLEA notices on a scheduled cadence during the active cycle; capture each distinct official file and round/vacancy snapshot.
- Fees/hostel: revisit at least annually and whenever a source reports a new academic-year schedule.
- Placement disclosures and rankings: revisit on publication cycles, retaining historical versions.
- Do not scrape aggressively. Keep retries bounded and obey access policy.

## 7. Five-year cutoff coverage audit protocol

The data team must create a repeatable report with one row per year × source × category. Minimum output columns:

`admission_year, source_found, source_url, downloaded, checksum, valid_pdf, page_count, extracted_rows, parsed_rows, rejected_rows, expected_categories, observed_categories, colleges_observed, branches_observed, null_dash_rate, duplicate_keys, value_range_errors, min_gt_max_count, spot_check_sample, reviewer_status, gap_reason`.

### Acceptance gates per year

A year may be marked `verified` only after all are true:

1. Source authenticity is established and the complete original is stored with checksum.
2. The document clearly identifies the admission cycle represented by the cutoff values.
3. The extracted table accounts for all pages/table sections and all categories in the source.
4. Composite-key duplicates are explained and resolved or explicitly held out.
5. Numeric bounds and suspicious MAX/MIN pairs are investigated.
6. A reproducible sample of extracted rows matches the rendered source.
7. Source page/table lineage exists for all published observations.

Possible statuses: `not_found`, `source_found_not_downloaded`, `downloaded_not_validated`, `partially_extracted`, `parsed_needs_review`, `verified`, `conflicting_sources`.

Do not display a “5-year trend” label for a college/branch/category that has only two verified years. Display actual years present (e.g., “2024–2025: 2 of 5 target years”) and distinguish missing year from no cutoff. “No cutoff published in a category” is not the same as a missing document.

## 8. Forecasting and machine-learning evaluation

### Target definition

The initial forecast target should be the next-cycle published **minimum cutoff mark** (and optionally published maximum mark) for a matched college/branch/category where historical records are comparable. The UI should call this a “forecast of published cutoff marks,” not “rank prediction,” unless a separate verified rank dataset is found.

### Training policy

1. Build baselines first:
   - previous-year value;
   - recent weighted average;
   - simple trend extrapolation, clipped only according to the source metric’s valid range and disclosed.
2. Add interpretable models such as Ridge/ElasticNet after the target and feature definitions are stable.
3. Evaluate tree-based models such as CatBoost/LightGBM only when record count, feature support and chronology are sufficient.
4. Do not train per college/branch/category series from two data points and claim robust ML. A pooled model may learn patterns across many entities, but its evaluation must still split by admission year and prevent future-information leakage.
5. Potential features: prior-year max/min marks, lagged trends, historical observation count, category, branch code, college identity, admission-year seat/vacancy changes where verified, whether the branch was offered, and documented process changes. Missing seat/demand covariates must not be imputed as if known.
6. Exclude data that would not have been available at forecast time. In particular, do not use final vacancy, final cutoff or post-admission variables to predict that same cycle.

### Backtesting design

- Use **rolling-origin / chronological backtesting**, never random row splitting.
- Example once 2023 is ingested: train on 2023 to predict 2024; train on 2023–2024 to predict 2025. More folds become possible only when further actual historical outcomes are available.
- If a verified final 2026 target becomes available, add a later holdout. Until then do not pretend it is a completed forecast test.
- Compare every candidate against the same baseline on the same eligible holdout records.
- Avoid leakage from multiple category rows belonging to the same original cutoff table, and keep all records for a target cycle in the correct temporal split.

### Metrics to report

- **MAE** in cutoff-mark units: primary, interpretable error measure.
- **Median absolute error**: robust view of typical error.
- **RMSE**: penalizes large misses.
- **Bias/mean error**: tells whether forecasts systematically over- or under-predict.
- **Prediction interval coverage and width**: tests whether uncertainty ranges are honest and useful.
- **Slice metrics** by category, branch family, district/college where sample size permits.
- Baseline improvement, sample count and data coverage must appear beside every model metric.

Do not publish a model as better based only on training accuracy. With very few historic cycles, confidence will remain low even if the model code is technically correct.

### Prediction confidence model

Expose two independent indicators:

- **Data coverage:** number of verified comparable years, missingness and source quality.
- **Model reliability:** backtest error, interval coverage and performance relative to baseline.

An example display could be: `Low confidence — 2 verified years; no 2026 final cutoff in training data; backtest limited.` Do not assign “high confidence” merely because a model returns a narrow interval.

### Model release gates

- Reproducible training run with pinned inputs, parser/data version, code commit and feature set.
- No temporal leakage in review tests.
- At least one true holdout year and sufficient sample count for the target slice; if only one small fold exists, label experimental.
- Baseline comparison plus slice diagnostics.
- Interval construction reviewed, with limitations stated.
- Predictions versioned and never overwrite actual observations.
- Actual-versus-predicted dashboard retained so future cycles can evaluate the system honestly.

## 9. API design (versioned JSON over HTTPS)

Prefix all endpoints with `/api/v1`. Generate OpenAPI docs from FastAPI and use typed response models. Use pagination (`limit`, `cursor` or `page`) and server-side filters; never ship the 30MB JSON archive to every browser.

### Public read/search endpoints

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/health` | Liveness/readiness; no internal secrets in response. |
| `GET /api/v1/admission-years` | Lists available cycles and per-year coverage status. |
| `GET /api/v1/colleges` | Search/filter by text, code, district, ownership and verified TNLEA participation year. |
| `GET /api/v1/colleges/{college_id}` | Verified profile, year-specific offerings, sources, fees and available placement evidence. |
| `GET /api/v1/branches` | Branch taxonomy, aliases and evidence by year. |
| `GET /api/v1/offerings` | College × branch × year, including known seat/vacancy facts and data status. |
| `GET /api/v1/cutoffs` | Filter by year, college, branch, category, measure and round; returns source and coverage metadata. |
| `GET /api/v1/cutoffs/trends` | Time series for a matched college/branch/category; no interpolation across missing years by default. |
| `GET /api/v1/forecasts` | Current published forecasts for a target year with interval, method, model version and confidence notes. |
| `GET /api/v1/fees` | Fee components with year/quota/cadence/refundability/source. |
| `POST /api/v1/fees/estimate` | User-input scenario for annual/whole-course costs. Return assumptions and missing items; do not save inputs by default. |
| `GET /api/v1/placements` | Filter by institution, cohort/year, branch and metric scope. |
| `GET /api/v1/placements/compare` | Comparable institution/branch metrics only when reporting scopes are compatible. |
| `GET /api/v1/rankings` | Ranking-system-specific records and methodology/year. |
| `GET /api/v1/career-pathways` | Branch-to-skill/role pathway data with evidence and disclaimers. |
| `POST /api/v1/admission/assess` | Compares the student’s supplied score/category to matched historical marks; returns descriptive historical comparisons, not seat probability unless separately validated. |
| `POST /api/v1/recommendations` | Explainable shortlist based on user preferences, eligibility constraints, budget, location, branch and historic evidence. |
| `GET /api/v1/sources/{source_id}` | Source title, URL, retrieval date, verification state and fields supported. |

### Admin-only endpoints

`POST /api/v1/admin/sources`, `POST /api/v1/admin/ingestion-runs`, `POST /api/v1/admin/ingestion-runs/{id}/validate`, `POST /api/v1/admin/ingestion-runs/{id}/publish`, `GET /api/v1/admin/quality-issues`, `PATCH /api/v1/admin/quality-issues/{id}`, `POST /api/v1/admin/models/{model_id}/publish`.

Protect admin routes with authentication and role-based access. Keep secrets in environment variables. Add rate limits to expensive comparison and recommendation endpoints as needed.

### Example response shape for cutoffs

```json
{
  "items": [
    {
      "admission_year": 2025,
      "college_code": "4960",
      "branch_code": "AD",
      "category": "OC",
      "measure": "published_min_marks",
      "value": 72.119,
      "unit": "marks_or_average_as_published",
      "status": "verified_source_row",
      "source": {
        "title": "Previous Year 2025 Maximum & Minimum Cut-off",
        "url": "https://www.tnlea.com/QuickLinks/LEA-2026/Previous_Year_cutoff2025.pdf",
        "page": 1
      }
    }
  ],
  "coverage": {
    "available_years": [2024, 2025],
    "target_years": [2022, 2023, 2024, 2025, 2026],
    "missing_or_unverified_years": [2022, 2023, 2026],
    "note": "A missing year is not a zero cutoff. Source status is shown per year."
  }
}
```

The sample is illustrative of response structure; do not use its numeric row as a live verified API value without looking it up in the curated database.

## 10. Student recommendation engine

Start with explainable rules. Recommendation should be a shortlist and comparison aid, not a guarantee of admission.

### Inputs

- Current TNLEA score/mark as defined by the official process, community/category if the student elects to provide it, branch preferences, district/travel preferences, budget, hostel requirement and other user constraints.
- Do not ask for unnecessary personal identifiers.

### Filter and rank sequence

1. Validate inputs and official eligibility conditions for the relevant admission year.
2. Filter out colleges/branches with no verified participation/availability evidence for the target year, or clearly mark historical-only participation.
3. Compare against the closest compatible historical cutoff metric and category; return the exact years used.
4. Divide results into **historically compatible**, **reach**, and **affordable alternatives**, defining thresholds transparently and not claiming probabilities unless probability calibration has been validated.
5. Add budget fit only when fee components and required duration are sufficiently covered. If costs are incomplete, show “cost estimate incomplete.”
6. Add career/placement comparison only where cohort scope is comparable and evidence exists.
7. Expose “Why this appears” with the metrics and source links that affected the recommendation.

Use a deterministic baseline initially. Only introduce learned ranking weights after user research, validation and fairness review. Keep ranking axes separate: `admission fit`, `budget fit`, `career evidence`, `distance`, and `user preference` rather than one opaque “best college” score.

## 11. Placement and branch opportunity intelligence

### Placement data model

Store placements at the scope actually stated by the institution: overall institution, programme or branch. Required fields include cohort/reporting year, eligible students, placed students, placement rate if published, median package, average package, highest package, internship count if published, higher-study count if published, recruiter list if evidenced, unit/currency and source URL/page.

Never infer branch-specific placement from a college-wide figure. Never divide by an unknown denominator. Use a formula such as `placed_students / eligible_students * 100` only when both counts refer to the same cohort and the institution’s definitions are documented.

### Graphs

- 3–5 year trend when multiple comparable years exist: median package, rate and counts.
- Branch comparison with the reporting year and population shown.
- College-vs-branch comparison matrix.
- Total-cost vs median-package scatter plot only when both sides are valid and the chart clearly says correlation is not causation and salary is not guaranteed.
- Missing-data coverage chart and freshness labels.
- Recruiter/role panels only for source-supported lists; treat marketing claims separately from placement metrics.

### Career pathways

Branch-to-role information (e.g., software, embedded systems, mechanical design, civil engineering, electronics, data, cybersecurity) should be presented as general pathways plus suggested skills/projects. It is not proof that a particular college places students into those roles. Link each factual claim to its own evidence category.

## 12. UI architecture and visual quality

### Main pages

1. **Home / Admission Command Center:** cutoff coverage snapshot, student search entry, target-cycle status and recently verified notices.
2. **College explorer:** searchable directory with district, participation year, branch, costs-data availability and evidence status.
3. **College detail:** profile, year-by-year offerings, cutoff timeline, source-backed fees, placement evidence, facilities and data gaps.
4. **Cutoff time machine:** year/category/branch switches; actual published MAX/MIN data; missing years marked as gaps; forecast band visibly separated from actuals.
5. **Forecast lab:** model method, training years, holdout metrics, prediction interval and explanation.
6. **Cost calculator:** fee component breakdown, one-time/refundable/monthly/annual distinctions, user-entered travel/living assumptions and missing-cost warning.
7. **Career intelligence:** branch pathways, verified placement comparison and skill roadmap.
8. **Compare:** user-selected colleges/branches with aligned years and identical metric definitions.
9. **Sources & data status:** public provenance, freshness, correction contact and coverage by year.
10. **Admin review console:** restricted source/import queue, parsed values, page excerpts, difference review and publish controls.

### Design contract

- Keep the existing premium direction (forest/cream/gold or another deliberate accessible palette) if consistent with the current brand; ensure contrast, readable tables and clear chart legends.
- Use subtle transitions and strong typography rather than constant particle effects or excessive parallax.
- `prefers-reduced-motion` must work; provide static fallbacks.
- Tables need keyboard navigation, filter labels, mobile alternatives and CSV export where useful.
- Charts need text summaries/accessible alternatives and clear units.
- The word “forecast” must be visible on estimates, and actual values must not share the same visual encoding as projected values.
- Tamil/English translations must be reviewed by a human for admissions terminology. Persist the original English labels and source wording alongside localized labels.
- Every source-backed detail should have a nearby “Source / last checked” affordance.

## 13. Security, reliability and operational safeguards

- Store credentials in environment secrets, never in frontend bundles or committed `.env` files.
- Separate public read endpoints and admin ingestion/publish endpoints.
- Validate all query params, bound page sizes and limit expensive searches.
- Use SQL parameterization/ORM, migrations and least-privilege DB credentials.
- Back up PostgreSQL and raw documents; test restore steps at least quarterly.
- Record application, ingestion and model errors without logging student community/score input unnecessarily.
- Add schema, parser, duplicate, API-contract, accessibility and end-to-end tests.
- Keep source snapshots immutable and database changes auditable.
- Publish a correction pathway and data disclaimer. Have a human review high-impact data conflicts.

## 14. Phased implementation checklist

### Phase 0 — Baseline and gap closure (first milestone)
- [ ] Freeze current project archive and generate SHA-256 manifest.
- [ ] Reconcile the 16,317-row and 30,716-row cutoff CSVs.
- [ ] Re-download/validate the identified official 2023 cutoff source.
- [ ] Search for and document the status of 2022 and final 2026 cutoff evidence.
- [ ] Spot-check all cutoff extraction logic against rendered source pages.
- [ ] Create per-year/category/college/branch coverage report.
- [ ] Mark every unverified field or dataset as a gap; do not display zero defaults.

### Phase 1 — Database and ingestion foundation
- [ ] Implement PostgreSQL schema and Alembic migrations.
- [ ] Create source registry, raw file storage, content hashes and ingestion-run tracking.
- [ ] Build staging parser for cutoff PDFs and branch-code dictionaries.
- [ ] Implement normalization/identity-review workflow for college codes and branch names.
- [ ] Add automated data-quality gates and unit tests.
- [ ] Import only verified rows; publish provenance links with all cutoff records.

### Phase 2 — Cutoff API and student-facing alpha
- [ ] Build FastAPI search, historical cutoff and trend endpoints.
- [ ] Build Next.js English/Tamil navigation and typed API client.
- [ ] Add cutoff table, college/branch/category filters, CSV export and source links.
- [ ] Display data coverage by year and explicit historical-only participation labels.
- [ ] Reproduce the previous static project’s useful features against the API rather than loading the 30MB JSON into the browser.
- [ ] Test mobile, keyboard accessibility and reduced motion.

### Phase 3 — Forecasting research, not yet a public promise
- [ ] Implement baseline forecast methods and rolling-origin backtests.
- [ ] Add automated leakage tests and baseline comparisons.
- [ ] Store model versions, training data fingerprints and metrics.
- [ ] Add interval estimation and data/model confidence separately.
- [ ] Publish predictions only if release gates pass; otherwise show scenario/trend view with experimental label.
- [ ] Build actual-vs-predicted reporting for future admissions cycles.

### Phase 4 — Fees, placements and opportunity intelligence
- [ ] Create source-backed fee schedule collection and component schema.
- [ ] Collect institution and branch placement reports with cohort definitions.
- [ ] Import NIRF ranking observations separately by ranking year/category.
- [ ] Add total-course-cost estimator and incomplete-cost warnings.
- [ ] Add placement and career graphs with comparable-scope checks.
- [ ] Expand coverage by source-backed priority rather than filling unknown values.

### Phase 5 — Explainable recommendations and launch
- [ ] Implement deterministic admission-fit, budget-fit and preference ranking.
- [ ] Add reach / historically compatible / affordable alternatives with explanations.
- [ ] Add college comparison and downloadable report.
- [ ] Add source freshness/quality dashboard and correction workflow.
- [ ] Set up monitoring, backups, domain, production configuration and runbook.
- [ ] Conduct manual counselling-content review and student usability tests.
- [ ] Publish limitations and avoid claims of guaranteed admissions or guaranteed salaries.

### Phase 6 — Continuous improvements
- [ ] Add newly available admission-cycle data after source validation.
- [ ] Retrain/re-evaluate forecasts only with comparable outcomes and versioned datasets.
- [ ] Add regional route distance, scholarship and facilities data when adequately sourced.
- [ ] Add optional accounts/saved lists only after a privacy review.
- [ ] Revisit hosting/caching only after observing load and cost.

## 15. Go-live acceptance criteria

- Every displayed cutoff can be traced to an official or appropriately labelled source and a raw record.
- Every cutoff chart distinguishes published values from predictions and missing years.
- No fake rank values, zero-filled dashes, fabricated fees, fabricated placement statistics or unsupported branch availability.
- The import pipeline is rerunnable and idempotent, with testable duplicate handling.
- The 2024/2025 row-count discrepancy is understood and resolved or explicitly partitioned into documented extracts.
- 2023 is marked verified only after its full PDF is stored, validated and re-extracted; 2022/2026 remain visibly unavailable until evidence is validated.
- Prediction reports include chronological holdout metrics, baseline comparison, sample count and uncertainty; otherwise prediction is labelled experimental.
- Placement rates use known denominators and comparable cohorts; highest salary is never presented as typical salary.
- Fee calculations distinguish recurring, one-time, refundable and monthly costs and show assumptions.
- Tamil/English labels, keyboard access, mobile layout, reduced motion, database backup and restore have been tested.

## 16. Source references to begin with

- Official TNLEA portal: https://www.tnlea.com/
- Official 2026 portal — Round 1 vacancy position (not a final-cutoff table): https://www.tnlea.com/vacancy-position
- Official 2025 cutoff table published for the 2026 admission cycle, containing previous-year 2025 MAX/MIN cutoffs: https://www.tnlea.com/QuickLinks/LEA-2026/Previous_Year_cutoff2025.pdf
- Official 2024 admission page/document with previous-year 2023 MAX/MIN cutoffs: https://tnlea.com/supplementary_2024/links/Previous_Year_Cut-Off.pdf
- Official 2025-admission cutoff PDF with previous-year 2024 MAX/MIN cutoffs: https://www.tnlea.com/QuickLinks/LEA-2025/Previous%20Year%20%282024%29%20cutoff%20-%20LEA%202025.pdf
- Official NIRF 2025 Engineering rankings: https://www.nirfindia.org/Rankings/2025/EngineeringRanking.html
- Anna University official fee-structure page for its University Departments/Constituent Colleges: https://www.annauniv.edu/feestructure.php

These sources demonstrate initial discovery targets; they do not establish complete statewide coverage. Recheck current pages and source document versions before importing or publishing data.

---

## Final implementation rule

**Trustworthy coverage before clever prediction; explainable recommendations before opaque scores; actual data before visual polish.** Build the data foundation once so cutoff forecasting, fees, placements, branch opportunities and the bilingual student experience all use the same evidence-backed source of truth.
