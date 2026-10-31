from __future__ import annotations
import csv, json, os, re, sqlite3, threading, urllib.error, urllib.request
from pathlib import Path
from contextlib import contextmanager
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator

ROOT=Path(__file__).resolve().parent
DATA=ROOT/'data'
DB=Path(os.getenv('TNLEA_DB_PATH', '/tmp/tnlea_compass.db')).resolve()
DB.parent.mkdir(parents=True, exist_ok=True)
INIT_LOCK=threading.Lock()
TABLES={'colleges':'TNLEA_Colleges.csv','branches':'TNLEA_College_Branches.csv','cutoffs':'TNLEA_Historical_Admissions.csv','sources':'TNLEA_Source_Register.csv','fees':'TNLEA_Fee_Records.csv'}
app=FastAPI(title='TNLEA Compass API',version='1.1.0',description='Evidence-labelled Tamil Nadu lateral-entry admissions research API')
origins=[x.strip() for x in os.getenv('CORS_ORIGINS','').split(',') if x.strip()]
if origins:
    app.add_middleware(CORSMiddleware,allow_origins=origins,allow_methods=['GET','POST'],allow_headers=['Content-Type'])

def ident(v:str)->str:
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*',v): raise ValueError('Invalid SQL identifier')
    return '"'+v+'"'

def _connect(path=None):
    c=sqlite3.connect(str(path or DB),timeout=20); c.row_factory=sqlite3.Row
    c.execute('PRAGMA busy_timeout=20000'); return c

@contextmanager
def conn():
    c=_connect()
    try: yield c
    finally: c.close()

def init_db(force=False):
    """Seed database once. Existing valid data is never dropped on application restart."""
    with INIT_LOCK:
        if DB.exists() and DB.stat().st_size and not force:
            with conn() as c:
                names={r['name'] for r in c.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                if all(t in names for t in TABLES): return
        tmp=DB.with_suffix(DB.suffix+'.building'); tmp.unlink(missing_ok=True)
        c=_connect(tmp)
        try:
            for table,filename in TABLES.items():
                src=DATA/filename
                if not src.is_file(): raise RuntimeError(f'Missing required dataset: {filename}')
                with src.open(encoding='utf-8-sig',newline='') as f:
                    reader=csv.DictReader(f); original=reader.fieldnames or []
                    columns=[x.strip().replace(' ','_') for x in original]
                    if not columns: raise RuntimeError(f'Empty CSV header: {filename}')
                    c.execute(f'CREATE TABLE {ident(table)} (id INTEGER PRIMARY KEY AUTOINCREMENT,'+','.join(f'{ident(x)} TEXT' for x in columns)+')')
                    insert=f"INSERT INTO {ident(table)} ({','.join(ident(x) for x in columns)}) VALUES ({','.join('?' for _ in columns)})"
                    batch=[]
                    for row in reader:
                        batch.append([row.get(k,'') for k in original])
                        if len(batch)>=1000: c.executemany(insert,batch); batch.clear()
                    if batch: c.executemany(insert,batch)
                c.execute(f'CREATE INDEX idx_{table}_id ON {ident(table)}(id)')
            c.execute('CREATE TABLE _meta (key TEXT PRIMARY KEY,value TEXT NOT NULL)')
            c.execute("INSERT INTO _meta VALUES ('schema_version','2')")
            c.commit()
        except Exception:
            c.close(); tmp.unlink(missing_ok=True); raise
        else: c.close()
        os.replace(tmp,DB)

@app.on_event('startup')
def startup(): init_db()

@app.get('/')
def home(): return FileResponse(ROOT/'app'/'index.html')
@app.get('/api/health')
def health():
    with conn() as c: counts={t:c.execute(f'SELECT COUNT(*) FROM {ident(t)}').fetchone()[0] for t in TABLES}
    return {'status':'ok','version':app.version,'database':'sqlite','records':counts,'data_note':'Supplied research extract only; see /api/quality.'}
@app.get('/api/summary')
def summary():
    with conn() as c: return {t:c.execute(f'SELECT COUNT(*) FROM {ident(t)}').fetchone()[0] for t in TABLES}
@app.get('/api/quality')
def quality():
    with conn() as c: n=c.execute('SELECT COUNT(*) FROM cutoffs').fetchone()[0]
    return {'status':'limited_research_dataset','cutoff_years_available':[2024,2025],'cutoff_rows_in_supplied_csv':n,'limitations':['2023 source coverage is partial/unverified','2024/2025 supplied records are not exhaustive statewide coverage','No verified 2026 final cutoff dataset','Historical MIN/MAX values are published marks, not ranks','Fee records are sparse; missing values are unknown, not zero','No verified statewide placement or sanctioned-seat coverage'],'forecasting':'Descriptive comparisons only; no production ML forecast.'}
@app.get('/api/colleges')
def colleges(q:str='',district:str='',limit:int=Query(100,ge=1,le=500),offset:int=Query(0,ge=0)):
    sql='SELECT * FROM colleges WHERE 1=1'; args=[]
    if q.strip(): sql+=' AND (official_name LIKE ? OR former_name LIKE ? OR tnlea_college_code LIKE ?)'; args += [f'%{q.strip()}%']*3
    if district.strip(): sql+=' AND district LIKE ?'; args.append(f'%{district.strip()}%')
    sql+=' ORDER BY official_name LIMIT ? OFFSET ?'; args += [limit,offset]
    with conn() as c:
        items=[dict(r) for r in c.execute(sql,args)]; total=c.execute('SELECT COUNT(*) FROM colleges').fetchone()[0]
    return {'items':items,'total':total,'limit':limit,'offset':offset}
@app.get('/api/branches')
def branches(college_code:str='',branch_code:str='',limit:int=Query(200,ge=1,le=1000)):
    sql='SELECT * FROM branches WHERE 1=1'; args=[]
    if college_code: sql+=' AND college_code=?'; args.append(college_code.strip())
    if branch_code: sql+=' AND branch_code=?'; args.append(branch_code.strip())
    sql+=' ORDER BY college_code,branch_code LIMIT ?'; args.append(limit)
    with conn() as c: items=[dict(r) for r in c.execute(sql,args)]
    return {'items':items,'count':len(items)}
@app.get('/api/cutoffs')
def cutoffs(college_code:str='',branch_code:str='',category:str='',year:int|None=Query(None,ge=2000,le=2100),limit:int=Query(200,ge=1,le=1000)):
    sql='SELECT * FROM cutoffs WHERE 1=1'; args=[]
    for col,val in [('college_code',college_code.strip()),('branch_code',branch_code.strip()),('reservation_category',category.strip()),('admission_year',str(year) if year else '')]:
        if val: sql+=f' AND {ident(col)}=?'; args.append(val)
    sql+=' ORDER BY admission_year DESC LIMIT ?'; args.append(limit)
    with conn() as c: items=[dict(r) for r in c.execute(sql,args)]
    return {'items':items,'count':len(items),'metric_note':'Published cutoff marks; do not interpret as rank.'}
@app.get('/api/fees')
def fees(college:str='',district:str='',limit:int=Query(100,ge=1,le=500)):
    sql='SELECT * FROM fees WHERE 1=1'; args=[]
    if college: sql+=' AND institution LIKE ?'; args.append(f'%{college.strip()}%')
    if district: sql+=' AND district LIKE ?'; args.append(f'%{district.strip()}%')
    sql+=' ORDER BY institution LIMIT ?'; args.append(limit)
    with conn() as c: items=[dict(r) for r in c.execute(sql,args)]
    return {'items':items,'count':len(items),'note':'Only sourced fee records are shown; missing amounts are unknown, not zero.'}
@app.get('/api/sources')
def sources(limit:int=Query(200,ge=1,le=500)):
    with conn() as c: items=[dict(r) for r in c.execute('SELECT * FROM sources ORDER BY source_id LIMIT ?',(limit,))]
    return {'items':items,'count':len(items)}
class VacancyRequest(BaseModel):
    collegeCode:str=Field(min_length=1,max_length=12,pattern=r'^[A-Za-z0-9_-]+$')
    @field_validator('collegeCode')
    @classmethod
    def trim(cls,v): return v.strip()
@app.post('/api/live/vacancy')
def live_vacancy(body:VacancyRequest):
    payload=json.dumps({'collegeCode':body.collegeCode}).encode()
    req=urllib.request.Request('https://www.tnlea.com/api/user/vacancy-position',data=payload,headers={'Content-Type':'application/json','Accept':'application/json','User-Agent':'TNLEA-Compass/1.1'},method='POST')
    try:
        with urllib.request.urlopen(req,timeout=10) as res:
            raw=res.read(2_000_001)
            if res.status!=200 or len(raw)>2_000_000: raise HTTPException(502,'Official TNLEA service returned an invalid response')
            data=json.loads(raw.decode('utf-8'))
    except HTTPException: raise
    except (urllib.error.URLError,TimeoutError,ValueError,UnicodeDecodeError) as e: raise HTTPException(502,detail=f'Official TNLEA vacancy source unavailable ({type(e).__name__})') from e
    return {'source':'TNLEA official vacancy-position API','college_code':body.collegeCode,'retrieved_from_source':True,'data':data,'interpretation':'Published vacancy-position response; not sanctioned intake or a guarantee of currently available seats.'}
@app.get('/api/live/sources')
def live_sources(): return {'source':'https://www.tnlea.com/','checked_on_request':False,'note':'Official portal reference only; no background freshness monitor is claimed.'}
