#!/usr/bin/env bash
# Round-3 run at efa1e042 inside a real Herdr lab pane with a supervisor's leaked exports.
# usage: hosted-final.sh <tree> <workdir> <evidence>. Each rc is captured directly, never through a pipe.
tree=$1 W=$2 E=$3; d=$W/decoy; mkdir -p "$d/config" "$d/state" "$d/data" "$d/projects" "$W/logs"
export FM_HOME=$d FM_ROOT=$d FM_ROOT_OVERRIDE=$d FM_STATE_OVERRIDE=$d/state FM_DATA_OVERRIDE=$d/data \
  FM_CONFIG_OVERRIDE=$d/config FM_PROJECTS_OVERRIDE=$d/projects FM_BACKEND=herdr TERM_PROGRAM=herdr
unset FM_GATE_REFUSE_BYPASS NO_MISTAKES_GATE
out=$E/suite-results-final.txt; : > "$out"
{ echo "head=$(git -C "$tree" rev-parse --short HEAD)"; env | grep -E '^(HERDR_|TERM_PROGRAM=|FM_(HOME|BACKEND|STATE_OVERRIDE)=)' | sed "s#$W#\$W#g" | sort; } > "$E/launcher-env-final.txt"
cd "$tree"
for s in fm-test-fixtures fm-session-lock-ancestry fm-spawn-dispatch-profile fm-spawn-orca-worktree; do
  t0=$SECONDS; bash tests/$s.test.sh > "$W/logs/$s.log" 2>&1; rc=$?
  echo "$rc $((SECONDS-t0))s $s" >> "$out"
done
t0=$SECONDS; bin/fm-test-run.sh tests/fm-backend.test.sh tests/fm-control.test.sh tests/fm-teardown.test.sh > "$W/logs/fm-test-run.log" 2>&1; rc=$?
echo "$rc $((SECONDS-t0))s bin/fm-test-run.sh(fm-backend,fm-control,fm-teardown)" >> "$out"
cp -r "$W/logs" "$E/logs-final"
touch "$W/done"
