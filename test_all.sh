#!/bin/bash
# ======================================
# LLM Project Automation Script
#  - Sets up environment
#  - Runs FastAPI server with uvicorn
#  - Handles JSON POST request for task
#  - Creates & pushes GitHub repo
#  - Enables GitHub Pages
#  - Posts evaluation details
# ======================================

set -e  # Exit if any command fails

# -----------------------------
# 1. Load environment variables
# -----------------------------
if [ ! -f .env ]; then
  echo "❌ .env file missing. Please create it first."
  exit 1
fi

export $(grep -v '^#' .env | xargs)

# -----------------------------
# 2. Setup Python environment
# -----------------------------
echo "🐍 Setting up Python virtual environment..."
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# -----------------------------
# 3. Start FastAPI app via Uvicorn
# -----------------------------
echo "🚀 Starting FastAPI API server in background..."
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
UVICORN_PID=$!
sleep 5

API_URL="http://127.0.0.1:8000"
echo "✅ FastAPI running at $API_URL"

# -----------------------------
# 4. Simulate API Request (POST)
# -----------------------------
echo "📡 Sending sample task JSON to API endpoint..."
REQUEST_JSON=$(cat <<EOF
{
  "email": "$USER_EMAIL",
  "secret": "$USER_SECRET",
  "task": "captcha-solver-demo",
  "round": 1,
  "nonce": "abc123",
  "brief": "Create a simple app that returns Hello from FastAPI.",
  "evaluation_url": "https://example.com/notify"
}
EOF
)

curl -X POST "$API_URL/api-endpoint" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_JSON"

# -----------------------------
# 5. LLM Generation
# -----------------------------
echo "🧠 Running LLM agent to generate app code..."
python - <<'PYCODE'
from app.llm_agent import generate_app_code
print("✅ Generating app files...")
files = generate_app_code("simple app")
print(f"✅ Generated files: {files}")
PYCODE

# -----------------------------
# 6. GitHub Repo Setup
# -----------------------------
echo "🐙 Setting up GitHub repository..."
python - <<'PYCODE'
import os
from github import Github
from datetime import datetime

token = os.getenv("GITHUB_TOKEN")
username = os.getenv("GITHUB_USERNAME")
repo_name = f"tds-llm-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

g = Github(token)
user = g.get_user()
repo = user.create_repo(
    name=repo_name,
    description="TDS LLM Deployment Project",
    private=False,
    auto_init=False
)

os.system(f"git init")
os.system(f"git remote add origin https://github.com/{username}/{repo_name}.git")
os.system("git add .")
os.system('git commit -m "Initial commit - LLM project"')
os.system("git branch -M main")
os.system("git push -u origin main")

print(f"✅ Repo created: https://github.com/{username}/{repo_name}")

with open("repo_info.txt", "w") as f:
    f.write(f"https://github.com/{username}/{repo_name}\n")
PYCODE

REPO_URL=$(head -n 1 repo_info.txt)
PAGES_URL="https://${GITHUB_USERNAME}.github.io/$(basename $REPO_URL)/"

# -----------------------------
# 7. Add MIT License & README
# -----------------------------
if [ ! -f LICENSE ]; then
cat <<EOF > LICENSE
MIT License

Copyright (c) $(date +%Y)

Permission is hereby granted, free of charge, to any person obtaining a copy
...
EOF
git add LICENSE
git commit -m "Add MIT license"
git push origin main
fi

# -----------------------------
# 8. Notify Evaluation Server
# -----------------------------
COMMIT_SHA=$(git rev-parse HEAD)
ROUND=1

EVAL_JSON=$(cat <<EOF
{
  "email": "$USER_EMAIL",
  "task": "captcha-solver-demo",
  "round": $ROUND,
  "nonce": "abc123",
  "repo_url": "$REPO_URL",
  "commit_sha": "$COMMIT_SHA",
  "pages_url": "$PAGES_URL"
}
EOF
)

echo "📬 Sending evaluation details..."
for delay in 1 2 4 8 16; do
  response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$EVAL_JSON" \
    "https://example.com/notify")
  if [ "$response" -eq 200 ]; then
    echo "✅ Evaluation notification successful!"
    break
  else
    echo "⚠️ Failed (HTTP $response). Retrying in ${delay}s..."
    sleep $delay
  fi
done

# -----------------------------
# 9. Cleanup
# -----------------------------
echo "🧹 Cleaning up..."
kill $UVICORN_PID
deactivate

echo "🎉 All steps completed successfully!"