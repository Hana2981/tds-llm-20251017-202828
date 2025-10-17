#!/bin/bash
# --------------------------------------
# Full Local Test + GitHub Upload + Notify
# Dynamic attachment encoding
# --------------------------------------

set -e

# ------------------------
# 0. Load .env variables
# ------------------------
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found. Exiting."
    exit 1
fi

for var in GITHUB_TOKEN GITHUB_USERNAME OPENAI_API_KEY USER_SECRET OPENAI_BASE_URL; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

# ------------------------
# 1. Setup virtual environment
# ------------------------
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt || pip install fastapi uvicorn httpx python-dotenv openai PyGithub jq

# ------------------------
# 2. Test FastAPI
# ------------------------
uvicorn app.main:app --reload &
UVICORN_PID=$!
sleep 5
curl -s http://127.0.0.1:8000/
kill $UVICORN_PID

# ------------------------
# 3. Test LLM agent
# ------------------------
python - <<END
from app.llm_agent import generate_app_code
brief = "Test project brief"
result = generate_app_code(brief)
print("Generated files:", result["files"].keys())
END

# ------------------------
# 4. GitHub repo creation + push
# ------------------------
REPO_NAME="tds-llm-project"
python - <<END
import os, subprocess
from github import Github

g = Github(os.getenv("GITHUB_TOKEN"))
user = g.get_user()
try:
    repo = user.get_repo("$REPO_NAME")
    print(f"Repo '$REPO_NAME' already exists.")
except:
    repo = user.create_repo("$REPO_NAME")
    print(f"Repo '$REPO_NAME' created.")

subprocess.run(["git", "init"], check=True)
subprocess.run(["git", "add", "."], check=True)
subprocess.run(["git", "commit", "-m", "Initial commit"], check=True)
subprocess.run(["git", "branch", "-M", "main"], check=True)
remote_url = f"https://{os.getenv('GITHUB_TOKEN')}@github.com/{os.getenv('GITHUB_USERNAME')}/{REPO_NAME}.git"
subprocess.run(["git", "remote", "add", "origin", remote_url], check=True)
subprocess.run(["git", "push", "-u", "origin", "main", "--force"], check=True)
print("✅ All files pushed to GitHub.")
END

# ------------------------
# 5. Encode attachments dynamically
# ------------------------
ATTACHMENTS_JSON="[]"
if [ -d "attachments" ]; then
    ATTACHMENTS_JSON=$(jq -n '[]')
    for f in attachments/*; do
        MIME=$(file --mime-type -b "$f")
        B64=$(base64 -w0 "$f")
        NAME=$(basename "$f")
        URI="data:$MIME;base64,$B64"
        ATTACHMENTS_JSON=$(echo "$ATTACHMENTS_JSON" | jq --arg name "$NAME" --arg url "$URI" '. += [{"name": $name, "url": $url}]')
    done
fi

# ------------------------
# 6. Send evaluation request
# ------------------------
TASK_ID="captcha-solver-example"
ROUND=1
NONCE=$(uuidgen)
EMAIL="student@example.com"
BRIEF="Create a captcha solver that handles ?url=https://.../image.png. Default to attached sample."
CHECKS=("Repo has MIT license" "README.md is professional" "Page displays captcha URL passed at ?url=..." "Page displays solved captcha text within 15 seconds")
EVALUATION_URL="https://example.com/notify"

JSON_PAYLOAD=$(jq -n \
    --arg email "$EMAIL" \
    --arg secret "$USER_SECRET" \
    --arg task "$TASK_ID" \
    --argjson round $ROUND \
    --arg nonce "$NONCE" \
    --arg brief "$BRIEF" \
    --argjson checks "$(printf '%s\n' "${CHECKS[@]}" | jq -R . | jq -s .)" \
    --argjson attachments "$ATTACHMENTS_JSON" \
    --arg evaluation_url "$EVALUATION_URL" \
    '{
        email: $email,
        secret: $secret,
        task: $task,
        round: $round,
        nonce: $nonce,
        brief: $brief,
        checks: $checks,
        attachments: $attachments,
        evaluation_url: $evaluation_url
    }'
)

echo "Sending evaluation request..."
curl -s -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$EVALUATION_URL"

echo "✅ Full test + GitHub push + dynamic evaluation request complete."
