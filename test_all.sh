#!/bin/bash
set -e

# -------------------------------
# 0️⃣ Variables
# -------------------------------
APP_DIR="app"
WEB_DIR="webapp"
REPO_NAME="task-$(date +%s)"
PORT=8000

# -------------------------------
# 1️⃣ Load environment variables
# -------------------------------
if [ ! -f ".env" ]; then
cat <<'EOF' > .env
GITHUB_USER=YOUR_GITHUB_USERNAME
GITHUB_TOKEN=YOUR_PERSONAL_ACCESS_TOKEN
OPENAI_API_KEY=YOUR_OPENAI_KEY
LLM_PROVIDER=openai
EOF
fi
export $(grep -v '^#' .env | xargs)

# -------------------------------
# 2️⃣ Setup Python environment
# -------------------------------
if [ ! -d ".venv" ]; then
    echo "🌀 Creating virtual environment..."
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "⬆️ Upgrading pip..."
pip install --upgrade pip

echo "📦 Installing dependencies..."
pip install fastapi uvicorn httpx python-dotenv openai PyGithub requests

# -------------------------------
# 3️⃣ Create backend files
# -------------------------------
mkdir -p $APP_DIR

# main.py
cat <<'PY' > $APP_DIR/main.py
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from .llm_agent import query_llm

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "LLM FastAPI App Running!"}

@app.post("/llm")
async def llm_endpoint(request: Request):
    data = await request.json()
    query = data.get("query", "")
    answer = query_llm(query)
    return JSONResponse({"answer": answer})
PY

# llm_agent.py
cat <<'PY' > $APP_DIR/llm_agent.py
import os
import openai
from dotenv import load_dotenv

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")

def query_llm(prompt: str) -> str:
    if not prompt:
        return "No query provided."
    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[{"role":"user","content":prompt}],
            max_tokens=200
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        return f"Error: {str(e)}"
PY

# repo_handler.py
cat <<'PY' > $APP_DIR/repo_handler.py
import os
from github import Github
from dotenv import load_dotenv

load_dotenv()
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_USER = os.getenv("GITHUB_USER")

def create_github_repo(name: str, description="Auto-generated repo"):
    g = Github(GITHUB_TOKEN)
    user = g.get_user()
    repo = user.create_repo(name=name, description=description)
    return repo.html_url
PY

# -------------------------------
# 4️⃣ Create simple frontend
# -------------------------------
mkdir -p $WEB_DIR
cat <<'HTML' > $WEB_DIR/index.html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>LLM Web App</title>
</head>
<body>
<h1>LLM Agent Web App</h1>
<form id="queryForm">
<input type="text" id="query" placeholder="Ask something...">
<button type="submit">Send</button>
</form>
<div id="response"></div>
<script>
document.getElementById('queryForm').onsubmit = async (e) => {
  e.preventDefault();
  const q = document.getElementById('query').value;
  const r = await fetch('/llm', {
    method: 'POST',
    headers: {'Content-Type':'application/json'},
    body: JSON.stringify({query:q})
  });
  const data = await r.json();
  document.getElementById('response').textContent = data.answer || 'No answer';
}
</script>
</body>
</html>
HTML

# -------------------------------
# 5️⃣ README.md & LICENSE
# -------------------------------
[ ! -f README.md ] && cat <<'EOF' > README.md
# Auto-generated FastAPI + LLM Agent App
Contains backend (FastAPI + LLM), repo handler, and simple frontend.
EOF

[ ! -f LICENSE ] && cat <<'EOF' > LICENSE
MIT License
EOF

# -------------------------------
# 6️⃣ GitHub repository creation
# -------------------------------
python3 - <<EOF
import os
from github import Github
token = os.environ.get("GITHUB_TOKEN")
user = Github(token).get_user()
name = "$REPO_NAME"
if name not in [r.name for r in user.get_repos()]:
    repo = user.create_repo(name=name, description="Auto-generated FastAPI + LLM Agent app", private=False)
    print(f"✅ Repository created: {repo.html_url}")
else:
    print(f"ℹ️ Repository already exists: {name}")
EOF

# -------------------------------
# 7️⃣ Git commit & push
# -------------------------------
git init || true
if ! git remote get-url origin &> /dev/null; then
    git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
fi
git add .
if ! git diff-index --quiet HEAD --; then
    git commit -m "Initial commit with backend + frontend + LLM agent"
fi
git branch -M main
git push -u origin main || true

# -------------------------------
# 8️⃣ Run FastAPI server
# -------------------------------
if lsof -i:$PORT &> /dev/null; then
    echo "⚠️ Port $PORT in use, killing..."
    kill $(lsof -t -i:$PORT)
fi
echo "🚀 Running FastAPI + LLM server..."
nohup uvicorn app.main:app --reload --port $PORT &> uvicorn.log &
API_PID=$!
echo "✅ Server running with PID $API_PID at http://127.0.0.1:$PORT"
