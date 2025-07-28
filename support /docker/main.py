import os
import subprocess
import tempfile
import yaml
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="VelocityDRIVE‑SP Web API")

# ──────────────────────────────────────────────────────────────
# CORS (개발 편의를 위해 허용; 운영 시 도메인 제한 권장)
# ──────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ──────────────────────────────────────────────────────────────
# 인라인 HTML (순수 JS fetch 사용)
# ──────────────────────────────────────────────────────────────
HTML_PAGE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>VelocityDRIVE‑SP GUI</title>
  <style>
    body{font-family:Arial,Helvetica,sans-serif;margin:2rem}
    input,select{padding:4px;margin:4px 0}
    #log{white-space:pre-wrap;background:#f5f5f5;border:1px solid #ccc;padding:8px;height:280px;overflow:auto}
  </style>
</head>
<body>
  <h1>VelocityDRIVE‑SP Quick GUI</h1>

  <form id="mup1-form">
    <label>Device&nbsp;(e.g.&nbsp;/dev/ttyACM0):<br>
      <input type="text" name="device" value="/dev/ttyACM0" size="40" required>
    </label><br>

    <label>Method:<br>
      <select name="method">
        <option value="get">get</option>
        <option value="fetch">fetch</option>
        <option value="ipatch">ipatch</option>
        <option value="post">post</option>
        <option value="put">put</option>
        <option value="delete">delete</option>
      </select>
    </label><br>

    <label>YAML Input (optional):
      <input type="file" name="input_file" accept=".yaml,.yml">
    </label><br>

    <button type="submit">Run mup1cc</button>
  </form>

  <h3>Result</h3>
  <div id="log">(waiting)</div>

  <script>
    const form = document.getElementById('mup1-form');
    const log  = document.getElementById('log');

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      log.textContent = 'Running…';

      const data = new FormData(form);
      try {
        const res = await fetch('/api/run-mup1cc', {method:'POST', body:data});
        const txt = await res.text();
        try {
          const js = JSON.parse(txt);
          log.textContent = JSON.stringify(js, null, 2);
        } catch { log.textContent = txt; }
      } catch (err) {
        log.textContent = 'Fetch error: ' + err;
      }
    });
  </script>
</body>
</html>
"""

# ──────────────────────────────────────────────────────────────
# 루트: HTML 반환
# ──────────────────────────────────────────────────────────────
@app.get("/", response_class=HTMLResponse)
async def root():
    return HTML_PAGE

# ──────────────────────────────────────────────────────────────
# 핵심 API: dr mup1cc 래핑
# ──────────────────────────────────────────────────────────────
@app.post("/api/run-mup1cc")
async def run_mup1cc(
    method: str = Form(...),
    device: str = Form(...),
    input_file: Optional[UploadFile] = File(None),
):
    temp_path: Path | None = None
    try:
        if input_file:
            suffix = Path(input_file.filename or "input").suffix or ".yaml"
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
            temp_path = Path(tmp.name)
            tmp.write(await input_file.read())
            tmp.close()

        cmd = ["dr", "mup1cc", "-d", device, "-m", method]
        if temp_path:
            cmd += ["-i", str(temp_path)]

        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if proc.returncode != 0:
            return JSONResponse(
                status_code=500,
                content={"error": proc.stderr.strip() or "mup1cc failed"},
            )

        stdout = proc.stdout.strip()
        try:
            parsed = yaml.safe_load(stdout)
            return {"output": parsed}
        except Exception:
            return {"output_raw": stdout}

    except subprocess.TimeoutExpired:
        return JSONResponse(status_code=504, content={"error": "mup1cc timeout"})
    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
    finally:
        if temp_path and temp_path.exists():
            temp_path.unlink()

# ──────────────────────────────────────────────────────────────
# 로컬 실행용
# ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
