#!/usr/bin/env bash
set -euo pipefail

# Sync upstream openclaw/<branch> into personal fork <branch>.
# Usage:
#   ./update.sh
#   ./update.sh <branch>
#   ./update.sh --rebase [branch]
#   ./update.sh --rebase --force-with-lease [branch]
#   ./update.sh --help

SOURCE_URL="git@github.com:openclaw/openclaw.git"
TARGET_URL="git@github.com:JoeZhu123/openclaw.git"
SOURCE_REMOTE="upstream"
TARGET_REMOTE="your-origin"
SYNC_MODE="merge"
BRANCH="main"
FORCE_WITH_LEASE=0

usage() {
  cat <<'EOF'
Usage:
  ./update.sh
  ./update.sh <branch>
  ./update.sh --rebase [branch]
  ./update.sh --rebase --force-with-lease [branch]
  ./update.sh --help

Options:
  --rebase            Rebase local branch onto upstream/<branch> (linear history).
  --force-with-lease Use force-with-lease when pushing (rebase mode only).
  --help              Show this help message.
EOF
}

for arg in "$@"; do
  case "${arg}" in
    --rebase)
      SYNC_MODE="rebase"
      ;;
    --force-with-lease)
      FORCE_WITH_LEASE=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Error: unknown option '${arg}'"
      usage
      exit 1
      ;;
    *)
      BRANCH="${arg}"
      ;;
  esac
done

if [[ "${FORCE_WITH_LEASE}" -eq 1 && "${SYNC_MODE}" != "rebase" ]]; then
  echo "Error: --force-with-lease can only be used with --rebase."
  usage
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: current directory is not a git repository."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: working tree is not clean. Commit or stash your changes first."
  exit 1
fi

echo "==> Ensuring remotes"
if git remote get-url "${SOURCE_REMOTE}" >/dev/null 2>&1; then
  git remote set-url "${SOURCE_REMOTE}" "${SOURCE_URL}"
else
  git remote add "${SOURCE_REMOTE}" "${SOURCE_URL}"
fi

if git remote get-url "${TARGET_REMOTE}" >/dev/null 2>&1; then
  git remote set-url "${TARGET_REMOTE}" "${TARGET_URL}"
else
  git remote add "${TARGET_REMOTE}" "${TARGET_URL}"
fi

echo "==> Fetching ${SOURCE_REMOTE}/${BRANCH} and ${TARGET_REMOTE}/${BRANCH}"
git fetch "${SOURCE_REMOTE}" "${BRANCH}"
git fetch "${TARGET_REMOTE}" "${BRANCH}" || true

echo "==> Checking out local ${BRANCH}"
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  git checkout "${BRANCH}"
else
  if git show-ref --verify --quiet "refs/remotes/${TARGET_REMOTE}/${BRANCH}"; then
    git checkout -b "${BRANCH}" --track "${TARGET_REMOTE}/${BRANCH}"
  else
    git checkout -b "${BRANCH}" "${SOURCE_REMOTE}/${BRANCH}"
  fi
fi

if [[ "${SYNC_MODE}" == "rebase" ]]; then
  echo "==> Rebasing ${BRANCH} onto ${SOURCE_REMOTE}/${BRANCH}"
  git rebase "${SOURCE_REMOTE}/${BRANCH}"
else
  echo "==> Merging ${SOURCE_REMOTE}/${BRANCH} into local ${BRANCH}"
  git merge --no-edit "${SOURCE_REMOTE}/${BRANCH}"
fi

echo "==> Pushing ${BRANCH} to ${TARGET_REMOTE}"
if [[ "${FORCE_WITH_LEASE}" -eq 1 ]]; then
  git push --force-with-lease "${TARGET_REMOTE}" "${BRANCH}:${BRANCH}"
else
  git push "${TARGET_REMOTE}" "${BRANCH}:${BRANCH}"
fi

echo "Done: synced ${SOURCE_REMOTE}/${BRANCH} -> ${TARGET_REMOTE}/${BRANCH} (mode: ${SYNC_MODE})"
