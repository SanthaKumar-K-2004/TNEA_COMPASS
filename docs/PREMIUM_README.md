# TNLEA Compass — Premium student planner

A responsive, offline-first single-page tool for TNLEA lateral-entry research. This is an independent research interface, not an official admissions portal.

## Start
1. Extract this package into a folder.
2. Open `index.html` in a modern browser. No build step or account is required.
3. Enter your qualifying aggregate percentage and community category under **Find my options**. Optionally filter branch, district, and historical year.
4. Use **Cutoff explorer** to search/compare observed MAX/MIN marks and export filtered CSV. Use **College directory** to search historical-profile colleges or load the full official 2025 counselling-code list. Use **Fees & hostel** and **Rules & sources** for source-linked disclosures and caveats.

## Features
- Student marks + community matcher against the locally included sampled history. Results are based on published historical minimum cutoff marks and are not admission probabilities or guarantees.
- Category-aware historical MAX/MIN cutoff explorer, with per-row source links and a clear separation from individual ranks.
- Simple 2027 linear-trend marker only when matching 2024 and 2025 MIN observations exist. Confidence is explicitly very low; it is not a trained/validated ML model.
- Verified fee/hostel cards where a college or university published an amount, component-level disclosure and year note. Missing amounts remain missing.
- College map links where location text is available.
- Source registry, eligibility threshold notes, CSV export, keyboard-focus states, mobile layout and reduced-motion support.
- Custom generated background illustration embedded in `index.html`, original SVG compass mark and optional Higgsfield-generated 4-second silent ambient video loaded only when the visitor clicks **Play ambience**. Static artwork and CSS motion remain when offline.
- Optional loader for the **426 unique college codes** extracted from the official TNLEA 2025 college-list PDF. The list had 430 source rows are preserved in the CSV; the search loader deduplicates to 426 unique codes. Code 1511 appears in five source rows with different PIN text (four repeats beyond the first), so check the original PDF for this discrepancy. The original PDF remains the authority.

## Evidence and scope
- Included cutoff table: **409 sampled category-level rows** across 2023, 2024 and 2025; 2023 is a partial indexed sample. 2024 and 2025 rows are still a sample from the full official PDFs, not an exhaustive extraction.
- Local college profiles: **15** with historical cutoff evidence, plus **113** college-branch-year evidence rows. When online, the 2025 directory loader adds entries from the official 14-page list (426 distinct college codes) to the directory search. This does not establish current participation or branch-level availability.
- Fees: three institutional fee/hostel schedules plus one Anna University RRA fee reference, each kept separate by fee type and year. This is not a full statewide fee schedule.
- Source register: 26 source/document references. Source dates, scope, limitations and URLs are preserved in `TNLEA_Source_Register.csv` and `data.json`.
- No individual opening/closing rank list is included because those values are not present in the cutoff rows used here. MAX/MIN are retained as cutoff marks/averages, not ranks.
- The 2026 final cutoff, 2022 history, all seat matrices, vacancies by round, all tuition/hostel fees, current approvals/accreditations, and complete placement data are not yet fully sourced. No estimates are inserted for those missing fields.

## Official sources
Primary sources used include the [TNLEA portal](https://www.tnlea.com/), the official 2025 [college-code list](https://www.tnlea.com/QuickLinks/LEA-2025/listofcollegs.pdf), 2025 [branch-code list](https://www.tnlea.com/QuickLinks/LEA-2025/list_of_branches.pdf), 2024 and 2025 cutoff PDFs, the 2026–27 candidate instructions, [Anna University fee page](https://annauniv.edu/dsa/collection-rra-fees.html), individual official college fee disclosures, AICTE and TANSCHE sources. See `TNLEA_Source_Register.csv` for the exact record log.

## Download the extracted official college directory
A separately hosted CSV created from the official 2025 PDF is available here: [TNLEA_Official_College_Directory_2025.csv](https://d2ol7oe51mr4n9.cloudfront.net/user_3L7wSQlSsVdGt7EKrLQfbTPWmFp/0a84317b-2c5e-47c3-8fd6-6ee045b79594.csv). It preserves all 430 parsed source rows and duplicate-code flags; use the original PDF to inspect exact layout and the five rows that share code 1511.

## Visual assets
- `assets/tnlea-cinematic-background.webp`: generated hero artwork.
- `HIGGSFIELD_MOTION_ASSET.md`: Higgsfield motion clip URL and usage details.
- The generated motion is decorative; it does not generate or change any admission data.

## Known limitations
The current package is a **functional research prototype**, not a fully verified production statewide counselling database. Several hundred current institution profiles can be discovered from the 2025 list, but full college-specific courses, seats, costs, accreditation, and placements require their own year-specific source verification. Confirm every admission-critical figure on the official source before applying or paying fees.


## Package files
- `index.html` — premium interactive dashboard with student marks matcher, cutoff explorer, college directory, fees/hostel, sources and optional motion.
- `TNLEA_Master_Database.xlsx` — filtered worksheets for colleges, branches, historical cutoffs, fees, fee components, fee sources, sources, eligibility, projections, data dictionary and quality notes.
- `TNLEA_Data_Quality_Report.xlsx` — coverage matrix, issues, source register and duplicate/anomaly notes.
- `TNLEA_Research_Report.pdf` — four-page coverage/methodology report.
- `TNLEA_Historical_Admissions.csv`, `TNLEA_Colleges.csv`, `TNLEA_College_Branches.csv`, `TNLEA_Fee_Records.csv`, `TNLEA_Fee_Sources.csv`, `TNLEA_Source_Register.csv` — normalized local data.
- `data.json` — browser-app dataset and source metadata.
- `assets/tnlea-cinematic-background.webp` — generated image fallback; image also embedded in the HTML.
- `HIGGSFIELD_MOTION_ASSET.md` — generated motion asset URL and behavior.
- `QUALITY_NOTES.md` and `FILE_MANIFEST.json` — evidence limitations and file integrity hashes.
- `screenshots/` — desktop, mobile and source-page previews.

The full 2025 college directory is supplied as a companion online CSV/ZIP and loaded into the browser app on demand; it is linked in `OFFICIAL_DIRECTORY_LINKS.md`. It is not represented as a fully verified branch/fee/seat census.


The separately hosted full source archive is linked in `OFFICIAL_DIRECTORY_LINKS.md`; it contains the original valid cutoff PDFs for 2024/2025, candidate instructions, branch dictionary, official 2025 college list, Anna University RRA page and one institution AICTE disclosure. Failed/invalid PDF URLs are documented, not stored as originals.
