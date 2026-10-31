#!/usr/bin/env bash
# Runs suites from inside a real Herdr lab pane with a supervisor's exports.
# usage: hosted-run.sh <tree> <label> <workdir> <evidence> [suite ...]  ; rc captured directly, never via a pipe.
tree=$1 label=$2 W=$3 E=$4; shift 4
d=$W/decoy-$label; mkdir -p "$d/config" "$d/state" "$d/data" "$d/projects"
export FM_HOME=$d FM_ROOT=$d FM_ROOT_OVERRIDE=$d FM_STATE_OVERRIDE=$d/state FM_DATA_OVERRIDE=$d/data \
  FM_CONFIG_OVERRIDE=$d/config FM_PROJECTS_OVERRIDE=$d/projects FM_BACKEND=herdr TERM_PROGRAM=herdr
unset FM_GATE_REFUSE_BYPASS NO_MISTAKES_GATE
env | grep -E '^(HERDR_|TERM_PROGRAM=|FM_(HOME|BACKEND|STATE_OVERRIDE)=)' | sed "s#$W#\$W#g" | sort > "$E/launcher-env-$label.txt"
cd "$tree"; mkdir -p "$W/logs-$label"
out=$E/suite-results-$label.txt; : > "$out"
export W label out
par=(); fg=()
for s in "$@"; do case $s in fm-spawn-dispatch-profile|fm-spawn-orca-worktree) fg+=("$s");; *) par+=("$s");; esac; done
one() { local s=$1 t0=$SECONDS rc; bash tests/$s.test.sh > "$W/logs-$label/$s.log" 2>&1; rc=$?; echo "$rc $((SECONDS-t0))s $s" >> "$out"; }
export -f one
printf '%s\n' "${par[@]}" | xargs -r -P 6 -I{} bash -c 'one {}'
# these two need the pane's foreground process group (they source an interactive shell), so no job or timeout wrapper
for s in "${fg[@]}"; do one "$s"; done
touch "$W/done-$label"
