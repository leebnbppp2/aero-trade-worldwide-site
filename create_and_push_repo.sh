#!/usr/bin/env bash
set -euo pipefail

TOKEN=$(python3 - <<'PY'
import os,re
from pathlib import Path

tok = os.getenv('GITHUB_TOKEN', '').strip()
if not tok:
    env = Path.home()/'.hermes'/'.env'
    if env.exists():
        for line in env.read_text(errors='ignore').splitlines():
            if line.startswith('GITHUB_TOKEN='):
                tok = line.split('=',1)[1].strip().strip('"').strip("'")
                break
if not tok:
    cred = Path.home()/'.git-credentials'
    if cred.exists():
        m = re.search(r'https://[^:]+:([^@]+)@github\.com', cred.read_text(errors='ignore'))
        if m:
            tok = m.group(1)
print(tok)
PY
)

if [ -z "$TOKEN" ]; then
  echo 'ERROR: no github token found'
  exit 1
fi

USER_JSON=$(curl -fsSL -H "Authorization: token $TOKEN" https://api.github.com/user)
USER_LOGIN=$(python3 -c 'import sys,json; print(json.load(sys.stdin)["login"])' <<< "$USER_JSON")
REPO_NAME="aero-trade-worldwide-site"
DESC="Temporary corporate website for AERO TRADE WORLDWIDE LIMITED"

HTTP_CODE=$(curl -s -o /tmp/aero_repo_create.json -w '%{http_code}' \
  -H "Authorization: token $TOKEN" \
  -H 'Accept: application/vnd.github+json' \
  -X POST https://api.github.com/user/repos \
  -d "{\"name\":\"$REPO_NAME\",\"description\":\"$DESC\",\"private\":false}")

if [ "$HTTP_CODE" = "201" ]; then
  CREATED="created"
elif [ "$HTTP_CODE" = "422" ]; then
  CREATED="exists"
else
  echo "repo create failed: HTTP $HTTP_CODE"
  cat /tmp/aero_repo_create.json
  exit 1
fi

if [ ! -d .git ]; then
  git init
  git checkout -b main
fi

git config user.name "Ubuntu"
git config user.email "ubuntu@localhost.localdomain"

git add .
if ! git diff --cached --quiet; then
  git commit -m "feat: add temporary corporate website"
fi

REMOTE_URL="https://github.com/$USER_LOGIN/$REPO_NAME.git"
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

PUSH_URL="https://$USER_LOGIN:$TOKEN@github.com/$USER_LOGIN/$REPO_NAME.git"
git push -u "$PUSH_URL" main >/tmp/aero_push.log 2>&1
LAST_COMMIT=$(git log -1 --oneline)
STATUS=$(git status --short)
printf '{"user":"%s","repo":"%s","state":"%s","remote":"%s","last_commit":"%s","status":"%s"}\n' "$USER_LOGIN" "$REPO_NAME" "$CREATED" "$REMOTE_URL" "$LAST_COMMIT" "$STATUS"
