#!/bin/bash

# -e so a failed clone, commit or push fails the build. Without it this script
# exits 0 even when nothing was committed, and the workflow step goes green
# while the rollout silently never happens.
# -u catches a missing argument instead of writing "image: .../:" into a manifest.
set -euo pipefail
set -x

# Set the repository URL
REPO_URL="https://github.com/olaolatunbos/Voting-AWS.git"

# Clone the git repository into the /tmp directory
rm -rf /tmp/temp_repo
git clone "$REPO_URL" /tmp/temp_repo
# Navigate into the cloned repository directory
cd /tmp/temp_repo

# A fresh clone does not inherit the credentials actions/checkout wrote into the
# workspace checkout's .git/config — those are local to that repo, not global —
# so cloning succeeds (public repo) but pushing would 403. Left unset when
# running by hand, where your own credential helper already handles it.
if [ -n "${GITHUB_TOKEN:-}" ]; then
  set +x  # keep the token out of the xtrace log
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/olaolatunbos/Voting-AWS.git"
  set -x
fi

# Git refuses to commit with an empty ident: "Author identity unknown".
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Make changes to the Kubernetes manifest file(s)
# For example, let's say you want to change the image tag in a deployment.yaml file
sed -i "s|image:.*|image: 801497981564.dkr.ecr.eu-west-2.amazonaws.com/$2:$3|g" voting-app/k8s-specifications/app/$1-deployment.yaml

# Add the modified files
git add .

# Re-running with a tag the manifest already carries stages nothing, and under
# set -e an empty git commit is a non-zero exit that would fail the build.
if git diff --cached --quiet; then
  echo "$1 already at $3; nothing to commit"
  exit 0
fi

# Commit the changes
git commit -m "Update Kubernetes manifest to $1:$3"

# Push the changes back to the repository
git push

# Cleanup: remove the temporary directory
rm -rf /tmp/temp_repo