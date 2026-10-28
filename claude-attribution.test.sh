#!/bin/sh
# Exercises the Claude attribution pre-push check.
# Run from anywhere: sh claude-attribution.test.sh

set -eu

hook_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
pre_push="$hook_dir/pre-push"

fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

assert_status() {
  expected=$1
  name=$2
  shift 2
  set +e
  "$@" >"$tmp/out" 2>"$tmp/err"
  status=$?
  set -e
  if [ "$status" -ne "$expected" ]; then
    echo "FAIL $name (exit $status, expected $expected)" >&2
    cat "$tmp/err" >&2
    fail=1
  else
    echo "ok $name"
  fi
}

git_quiet() {
  git -C "$repo" -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"
}

new_repo() {
  repo=$tmp/repo
  rm -rf "$repo"
  git init -q -b main "$repo"
  git_quiet config user.name "Hook Test"
  git_quiet config user.email "hook-test@example.com"
  find "$repo/.git/hooks" -type f -exec chmod a-x {} +
}

commit_on() {
  branch=$1
  file=$2
  msg=$3
  if git_quiet rev-parse --verify -q "refs/heads/$branch" >/dev/null; then
    git_quiet checkout -q "$branch"
  fi
  printf '%s\n' "$file" >"$repo/$file"
  git_quiet add "$file"
  git_quiet commit -q -m "$msg"
}

# main has a published Claude trailer. feature's remote tip does not contain
# main. Merging main in makes those existing commits show up in remote..local.
new_repo
commit_on main a "init"
commit_on main b "$(printf '%s\n' "old work" "" "Co-authored-by: Claude Opus 5.5 <noreply@anthropic.com>")"
commit_on main c "$(printf '%s\n' "notes" "" "Made with Claude Code")"
git_quiet checkout -q -b feature HEAD~2
commit_on feature d "feature work"
git_quiet update-ref refs/remotes/origin/main main
git_quiet update-ref refs/remotes/origin/feature feature
remote_feature=$(git_quiet rev-parse feature)
git_quiet merge -q -m "Merge main into feature" main
merge=$(git_quiet rev-parse HEAD)

run_push() {
  local_sha=$1
  remote_sha=$2
  ref=${3:-refs/heads/feature}
  printf '%s %s %s %s\n' "$ref" "$local_sha" "$ref" "$remote_sha" |
    (
      cd "$repo" || exit 1
      env -u KSM_CLAUDE_ATTRIBUTION_HOOK "$pre_push" origin "file://$tmp/dummy"
    )
}

assert_status 0 "merge of published Claude commits is allowed" \
  run_push "$merge" "$remote_feature"

commit_on feature e "$(printf '%s\n' "new work" "" "Co-authored-by: Claude <noreply@anthropic.com>")"
bad=$(git_quiet rev-parse HEAD)
assert_status 1 "new commit with a Claude trailer is refused" \
  run_push "$bad" "$remote_feature"

commit_on feature f "$(printf '%s\n' "prose" "" "Generated with Claude Code")"
bad=$(git_quiet rev-parse HEAD)
assert_status 1 "new commit with a generated-with line is refused" \
  run_push "$bad" "$remote_feature"

git_quiet checkout -q -b feature-clean "$merge"
commit_on feature-clean g "clean follow-up"
clean=$(git_quiet rev-parse HEAD)
assert_status 0 "clean commits on top of published history are allowed" \
  run_push "$clean" "$remote_feature"

# First push of a branch: remote sha is all zeros. Published commits are
# excluded via --remotes; a new trailer is still refused.
zero=0000000000000000000000000000000000000000
git_quiet checkout -q -b brand-new main
commit_on brand-new h "brand new clean"
brand=$(git_quiet rev-parse HEAD)
assert_status 0 "new branch carrying published Claude commits is allowed" \
  run_push "$brand" "$zero" refs/heads/brand-new

commit_on brand-new i "$(printf '%s\n' "brand new bad" "" "Made with Claude Code")"
brand=$(git_quiet rev-parse HEAD)
assert_status 1 "new branch with a new Claude line is refused" \
  run_push "$brand" "$zero" refs/heads/brand-new

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "all passed"
