#!/bin/bash

# ------------------------------
# Load environment variables
# ------------------------------
if [ ! -f .env ]; then
  echo "❌ .env file not found! Please create it with GITHUB_USER, GITHUB_TOKEN, and EVALUATION_URL."
  exit 1
fi

export $(grep -v '^#' .env | xargs)

# ------------------------------
# Set up Python virtual environment
# ------------------------------
echo "🌀 Setting up Python virtual environment..."
python3 -m venv .venv
source .venv/bin/activate

echo "⬆️ Upgrading pip..."
pip install --upgrade pip

echo "📦 Installing dependencies..."
pip install fastapi uvicorn httpx python-dotenv openai PyGithub requests

# Optional: gitleaks check
if ! command -v gitleaks &> /dev/null
then
    echo "⚠️ gitleaks not found. Install from https://github.com/zricethezav/gitleaks if needed."
else
    echo "✅ gitleaks is installed."
fi

# ------------------------------
# Run FastAPI server
# ------------------------------
echo "🚀 Running API server with Uvicorn..."
uvicorn app.main:app --reload &

API_PID=$!

# ------------------------------
# Python automation for GitHub
# ------------------------------
python3 <<EOF
import os, time, subprocess, json, random
from github import Github
import requests

token = os.getenv("GITHUB_TOKEN")
user = Github(token).get_user()
eval_url = os.getenv("EVALUATION_URL")

# ------------------------------
# Create unique repo
# ------------------------------
repo_name = f"task-{int(time.time())}"
repo = user.create_repo(
    name=repo_name,
    description="Auto-generated app repo",
    private=False,
    auto_init=True
)
print("✅ Repository created:", repo.html_url)

# ------------------------------
# Add MIT LICENSE
# ------------------------------
mit_text = """MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
...
"""
with open("LICENSE", "w") as f:
    f.write(mit_text)

# ------------------------------
# Add README.md if missing
# ------------------------------
if not os.path.exists("README.md"):
    with open("README.md", "w") as f:
        f.write(f"# {repo_name}\n\nAuto-generated repo with FastAPI app.\n")

# ------------------------------
# Initialize Git, commit all files
# ------------------------------
subprocess.run(["git", "init"], check=True)
subprocess.run(["git", "add", "."], check=True)
subprocess.run(["git", "commit", "-m", "Initial commit"], check=True)
subprocess.run(["git", "branch", "-M", "main"], check=True)
subprocess.run(["git", "remote", "add", "origin", repo.clone_url], check=True)
subprocess.run(["git", "push", "-u", "origin", "main"], check=True)
print("📂 All files pushed to GitHub")

# ------------------------------
# Optionally scan for secrets
# ------------------------------
if subprocess.run(["which", "gitleaks"]).returncode == 0:
    print("🔍 Running gitleaks scan...")
    subprocess.run(["gitleaks", "detect", "--source", ".", "--exit-code", "0"])

# ------------------------------
# Enable GitHub Pages
# ------------------------------
repo.edit(has_pages=True)
pages_url = f"https://{os.getenv('GITHUB_USER')}.github.io/{repo_name}/"
print("🌐 GitHub Pages enabled at:", pages_url)

# ------------------------------
# Function to POST to evaluation URL
# ------------------------------
def post_eval(round_number):
    payload = {
        "email": "student@example.com",
        "task": repo_name,
        "round": round_number,
        "nonce": f"nonce-{int(time.time())}",
        "repo_url": repo.html_url,
        "commit_sha": repo.get_commits()[0].sha,
        "pages_url": pages_url,
    }
    for delay in [1,2,4,8,16]:
        try:
            r = requests.post(eval_url, headers={"Content-Type":"application/json"}, data=json.dumps(payload))
            if r.status_code == 200:
                print(f"✅ Evaluation POST round {round_number} successful")
                return
            else:
                print(f"⚠️ Eval POST round {round_number} returned {r.status_code}, retrying in {delay}s...")
        except Exception as e:
            print(f"⚠️ Error posting round {round_number}: {e}, retrying in {delay}s...")
        time.sleep(delay)

# ------------------------------
# Round 1
# ------------------------------
post_eval(round_number=1)

# ------------------------------
# Simulate Round 2 modifications
# ------------------------------
print("✏️ Modifying code for round 2...")
# Example: append a comment to main.py
if os.path.exists("app/main.py"):
    with open("app/main.py", "a") as f:
        f.write(f"\n# Round 2 modification at {time.ctime()}")

# Update README.md
with open("README.md", "a") as f:
    f.write("\n## Round 2 Update\nAdded extra comment in main.py for round 2 demonstration.\n")

# Commit and push round 2
subprocess.run(["git", "add", "."], check=True)
subprocess.run(["git", "commit", "-m", "Round 2 updates"], check=True)
subprocess.run(["git", "push"], check=True)
print("📂 Round 2 changes pushed to GitHub")

# Update pages URL (already enabled)
post_eval(round_number=2)
EOF

# ------------------------------
# Finish
# ------------------------------
echo "🔹 Done! API is running in background with PID $API_PID"
echo "To stop the server, run: kill $API_PID"