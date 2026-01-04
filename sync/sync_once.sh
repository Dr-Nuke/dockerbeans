#!/usr/bin/env bash
#
# dockerbeans � ledger sync script
#
# Responsibilities:
# - Clone the private ledger repo if it does not exist
# - Otherwise, force-sync it to origin/master
# - Unlock encrypted files using git-crypt (symmetric key)
# - Perform a basic sanity check (file exists + beancount parse)
# - Send an email if *anything* goes wrong
#
# This script is safe to run repeatedly and is intended to be
# executed:
#   - once at container startup
#   - once per day via cron (02:00)
#

# Exit immediately on:
# - any command returning non-zero (-e)
# - use of unset variables (-u)
# - failures inside pipes (-o pipefail)
set -euo pipefail

# -------------------------------------------------------------------
# Helper: ensure required environment variables are set
# -------------------------------------------------------------------
require_env() {
  local name="$1"

  # ${!name:-} = indirect variable expansion
  # If the variable is unset or empty ? fail early with a clear message
  if [[ -z "${!name:-}" ]]; then
    echo "[dockerbeans][ERROR] Missing required env var: $name" >&2
    exit 2
  fi
}


# -------------------------------------------------------------------
# Validate required configuration
# -------------------------------------------------------------------
require_env GIT_SSH_URL     # e.g. git@github.com:user/ledger.git
require_env GIT_BRANCH     # master
require_env BEAN_FILE      # /data/repo/main.bean


# -------------------------------------------------------------------
# Define important paths
# -------------------------------------------------------------------
REPO_DIR="/data/repo"      # Shared volume location
STATE_DIR="/data/state"   # For last_success.txt, etc.
export BEAN_FILE_PATH="/data/repo/${BEAN_FILE}"

# Make sure required directories exist
mkdir -p "$STATE_DIR"


# -------------------------------------------------------------------
# Configure Git SSH
# -------------------------------------------------------------------
# We do NOT rely on ~/.ssh inside the container.
# Instead we explicitly tell git/ssh:
# - which private key to use
# - where the known_hosts file is
# - to refuse unknown hosts (no MITM surprises)
#
export GIT_SSH_COMMAND="ssh -i /run/secrets/dockerbeans-deploy-key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/run/secrets/known_hosts"
echo "GIT_SSH_COMMAND is set to $GIT_SSH_COMMAND"

# -------------------------------------------------------------------
# Failure handler
# -------------------------------------------------------------------
# Any meaningful failure should:
# - log clearly
# - trigger an email notification
# - exit with non-zero status
#
fail() {
  local message="$1"

  echo "[dockerbeans][FAIL] $message" >&2

  # Best-effort email notification.
  # Even if email fails, we still exit with failure.
  python /app/notify_email.py "$message" || true

  exit 1
}


echo "[dockerbeans] ==============================================="
echo "[dockerbeans] $(date -Is) Starting ledger sync"
echo "[dockerbeans] ==============================================="


# -------------------------------------------------------------------
# Clone or update repository
# -------------------------------------------------------------------
if [[ ! -d "$REPO_DIR/.git" ]]; then
  #
  # First run: repository does not exist yet
  #
  echo "[dockerbeans] Repository not found � performing initial clone"

  # Clean up any partial directory just in case
  rm -rf "$REPO_DIR"

  git clone \
    --branch "$GIT_BRANCH" \
    --single-branch \
    "$GIT_SSH_URL" \
    "$REPO_DIR" \
    || fail "Git clone failed (repo: $GIT_SSH_URL, branch: $GIT_BRANCH)"

else
  #
  # Normal case: repository already exists
  #
  echo "[dockerbeans] Repository found � syncing with origin/$GIT_BRANCH"

  # Fetch updates from origin, remove deleted remote branches
  (cd "$REPO_DIR" && git fetch --prune origin) \
    || fail "git fetch failed"

  # Hard reset ensures:
  # - no local changes
  # - exact match with origin/master
  # This is intentional: the Pi is read-only and disposable.
  (cd "$REPO_DIR" && git reset --hard "origin/$GIT_BRANCH") \
    || fail "git reset --hard failed (origin/$GIT_BRANCH)"
fi

# -------------------------------------------------------------------
# Unlock encrypted files using git-crypt
# -------------------------------------------------------------------
if [ "$ENABLE_GIT_CRYPT" = "true" ]; then
    # unlock repo

  echo "[dockerbeans] Unlocking repository with git-crypt"

  (cd "$REPO_DIR" && git-crypt unlock /run/secrets/gitcrypt.key) \
    || fail "git-crypt unlock failed (wrong key? corrupted repo?)"

else
  echo "[dockerbeans] git-crypt disabled, skipping unlock"
fi
# -------------------------------------------------------------------
# Sanity check: does the ledger file exist?
# -------------------------------------------------------------------
if [[ ! -f "$BEAN_FILE_PATH" ]]; then
  fail "Ledger file not found after unlock: $BEAN_FILE_PATH"
fi

echo "[dockerbeans] Ledger file found: $BEAN_FILE_PATH"


# -------------------------------------------------------------------
# Optional but recommended: beancount parse check
# -------------------------------------------------------------------
# This catches:
# - syntax errors
# - missing includes
# - truncated files
#
# It does NOT modify anything.
#
echo "[dockerbeans] Running basic beancount parse check"

python - <<'PY'
import os
import sys
from beancount.loader import load_file

bean_file_path = os.environ["BEAN_FILE_PATH"]

entries, errors, options = load_file(bean_file_path)

if errors:
    print(f"Beancount reported {len(errors)} error(s):", file=sys.stderr)
    for err in errors:
        # err is a Beancount error object with good __str__()
        print("-", err, file=sys.stderr)
    sys.exit(1)

print("Beancount parse OK")
PY

# If the Python block fails, the shell exits automatically
# due to `set -e`, which triggers the fail handler above.


# -------------------------------------------------------------------
# Record successful sync
# -------------------------------------------------------------------
date -Is > "$STATE_DIR/last_success.txt"

echo "[dockerbeans] Sync completed successfully at $(cat "$STATE_DIR/last_success.txt")"
echo "[dockerbeans] ==============================================="