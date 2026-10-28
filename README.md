# git-hooks

Global git hooks. `commit-msg` and `pre-push` reject Claude Code attribution. Every other hook name forwards to the repository's own hook, because `core.hooksPath` hides `.git/hooks`.

## Install

```bash
git clone git@github.com:timjonez/git-hooks.git
git config --global core.hooksPath /absolute/path/to/git-hooks
```

The hook scripts need to stay executable. A repository that sets its own `core.hooksPath` (Husky does this) uses that path instead.

## What is rejected

A commit message is refused when it contains any of these:

- `Made with … Claude` or `Generated with … Claude`
- `claude.com/claude-code`
- a `Co-authored-by` trailer whose name starts with `Claude`
- a `Co-authored-by` trailer addressed to `noreply@anthropic.com`

An ordinary `Co-authored-by` trailer is allowed. A subject that only names a Claude model is allowed.

`commit-msg` checks the message about to be committed. `pre-push` checks commits that are not already on a remote. Commits already on a remote stay as they are.

Set `KSM_CLAUDE_ATTRIBUTION_HOOK=1` to skip the check.

## Test

```bash
sh claude-attribution.test.sh
```
