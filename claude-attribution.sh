# Shared matcher for the Claude Code attribution lines.
# Sourced by commit-msg and pre-push. Not a git hook.

# Prints matching lines and returns 0 when the message carries Claude Code
# attribution. Returns 1 when the message is clean.
#
# Covers the commit trailer Claude Code writes today
# (Co-authored-by: Claude <noreply@anthropic.com>) and the prose form
# (Made with / Generated with Claude Code, including the claude.com link).
claude_attribution_matches() {
  LC_ALL=C grep -Ei \
    -e '^[[:space:]]*([^[:alnum:]]{0,12}[[:space:]]*)?(made|generated)[[:space:]]+with[[:space:]].*claude' \
    -e 'claude\.com/claude-code' \
    -e '^[[:space:]]*co-authored-by:[[:space:]]*claude([^[:alnum:]]|$)' \
    -e '^[[:space:]]*co-authored-by:[[:space:]]*.*<noreply@anthropic\.com>' \
    "$@"
}
