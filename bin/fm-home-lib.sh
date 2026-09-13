#!/usr/bin/env bash
# Shared "which home does this session actually operate on?" correction.
#
# A checkout carrying the .fm-secondmate-home identity marker bin/fm-home-seed.sh
# writes at seed time is a persistent second mate's OWN home, and its own session
# must always operate on that root. An inherited FM_HOME or FM_ROOT_OVERRIDE that
# disagrees with it is a launcher/environment leak - a restored pane, a reboot, or
# a backend server passing its own startup environment to a relaunched harness -
# not an intentional divergence, so it must not be trusted.
#
# A crewmate task worktree carries no marker, so its legitimate FM_HOME divergence
# toward its parent home is untouched, and a main home never carries one either.
# The marker is the same regular-file identity bin/fm-primary-scope-lib.sh owns;
# this check only needs to know the home IS a seeded secondmate root.
#
# This is the shell-layer owner of that correction, matching the extension-layer
# resolver in .pi/extensions/lib/fm-home-resolve.ts. Usage, right after SCRIPT_DIR
# is known and before any FM_HOME/STATE-derived path is computed:
#
#   FM_OWN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
#   # shellcheck source=bin/fm-home-lib.sh
#   . "$SCRIPT_DIR/fm-home-lib.sh"
#   fm_home_correct "$FM_OWN_ROOT" "${FM_HOME:-${FM_ROOT_OVERRIDE:-}}" "${FM_ROOT_OVERRIDE:-}"
#   FM_HOME=$FM_HOME_RESOLVED
#   FM_ROOT=$FM_ROOT_RESOLVED
#
# fm_home_correct always sets FM_HOME_RESOLVED and FM_ROOT_RESOLVED; callers
# decide whether to export them. It has no side effects on source.

fm_home_is_secondmate_root() {  # <root>
  local root=$1 marker
  [ -n "$root" ] || return 1
  marker="$root/.fm-secondmate-home"
  [ -L "$marker" ] && return 1
  [ -f "$marker" ] || return 1
  return 0
}

fm_home_correct() {  # <own-root> <requested-home> <requested-root>
  local own=$1 home=${2:-} root=${3:-}
  [ -n "$home" ] || home=$own
  [ -n "$root" ] || root=$own
  if fm_home_is_secondmate_root "$own"; then
    FM_HOME_RESOLVED=$own
    FM_ROOT_RESOLVED=$own
  else
    FM_HOME_RESOLVED=$home
    FM_ROOT_RESOLVED=$root
  fi
  return 0
}
