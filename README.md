# TNLEA Compass — Full-stack release candidate

This package combines the supplied Premium dashboard and research datasets with a FastAPI backend, SQLite seed builder, live TNLEA vacancy-position proxy, Docker/Render configuration, and automated tests. It is a newly assembled release candidate, not a recovered copy of the earlier v1.4.1 archive.

## Run locally

```bash
python -m venv .venv
# Windows: .venv\\Scripts\\activate
# Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
uvicorn server:app --reload
```

Open `http://127.0.0.1:8000`; API documentation is at `/docs`. The SQLite database is created atomically from `data/*.csv` on first startup. Subsequent restarts preserve an existing valid database. Set `TNLEA_DB_PATH` to choose another database location.

## Frontend/backend integration

The dashboard now checks `/api/health`, `/api/quality`, `/api/colleges` and `/api/cutoffs` when it loads and displays the API connection state. The College Directory includes an on-demand form that calls `POST /api/live/vacancy` using a TNLEA college code and displays the raw official response with its interpretation warning. The dashboard's research dataset remains embedded in the supplied HTML; the API's dataset is independently reported so the UI does not silently claim the two stores are identical.

## API

- `GET /api/health`, `/api/summary`, `/api/quality`
- `GET /api/colleges?q=&district=&limit=&offset=`
- `GET /api/branches?college_code=&branch_code=&limit=`
- `GET /api/cutoffs?college_code=&branch_code=&category=&year=&limit=`
- `GET /api/fees?college=&district=&limit=`
- `GET /api/sources?limit=`
- `POST /api/live/vacancy` JSON: `{"collegeCode":"2602"}`
- `GET /api/live/sources`

## Deployment

Use Render with the included Dockerfile and `render.yaml` (not a static-only Vercel deployment). Import the repository and deploy the Blueprint. The included free Render plan uses ephemeral storage: SQLite is rebuilt from the committed CSV seed data after a restart/redeploy. Runtime database writes are not durable. For durable user data, configure a persistent disk or managed PostgreSQL before adding write features. `CORS_ORIGINS` is optional and accepts a comma-separated allowlist; same-origin deployment needs no CORS middleware.

## Data integrity limitations

- Historical source values are preserved as text. Published `MIN`/`MAX` cutoff metrics are marks, not ranks.
- Supplied research files do not establish exhaustive statewide coverage. 2023 coverage is partial/unverified; 2024/2025 supplied extracts are not exhaustive; no verified 2026 final cutoff dataset is included.
- Fee records are sparse. Missing values mean unknown, not zero.
- No trained/validated ML forecast, guaranteed admission prediction, statewide placement database, or complete sanctioned-seat inventory is claimed.
- The live endpoint proxies TNLEA's official vacancy-position API. It is subject to TNLEA availability and does not represent sanctioned intake or guarantee seats currently available.

## Verification

```bash
python -m unittest discover -s tests -v
python -m py_compile server.py
```
