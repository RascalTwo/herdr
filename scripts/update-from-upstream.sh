#!/usr/bin/env bash
# Replay this fork's patch stack onto an upstream release tag, then verify.
#   scripts/update-from-upstream.sh          # newest upstream tag
#   scripts/update-from-upstream.sh v0.9.4   # a specific one
# Rebase (never merge) so `git log <tag>..HEAD` stays exactly the fork's delta. It takes a backup
# branch first and stops short of pushing. On a conflict: resolve, `git rebase --continue`, rerun.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[ "$(git branch --show-current)" = rascaltwo ] || { echo "run from the rascaltwo branch"; exit 1; }
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/herdrdev/herdr.git
git fetch --tags --quiet upstream
tag=${1:-$(git tag -l 'v[0-9]*' --sort=-v:refname | head -1)}
git rev-parse -q --verify "refs/tags/$tag" >/dev/null || { echo "no such tag: $tag"; exit 1; }

if git merge-base --is-ancestor "$tag" HEAD; then
  echo "already on $tag; verifying"
else
  [ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "commit or stash first"; exit 1; }
  base=$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD)   # the tag the stack sits on
  echo "files both sides touched ($base -> $tag) — expect conflicts here:"
  comm -12 <(git diff --name-only "$base" HEAD | sort) <(git diff --name-only "$base" "$tag" | sort) | sed 's/^/  /'
  git branch "backup/pre-$tag-$(date +%Y%m%d-%H%M%S)"
  git rebase --onto "$tag" "$base"
fi

cargo nextest run --locked --status-level fail --final-status-level fail --failure-output final --success-output never
cargo build --release --locked
./target/release/herdr --version
echo "ok. $(git rev-list --count "$tag"..HEAD) fork commit(s) on $tag. Push with: git push --force-with-lease"
