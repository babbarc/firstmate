#!/usr/bin/env bash
# usage: hosted-extra.sh <tree> <workdir> <evidence>: runner path, then lock-ancestry where init reaps orphans.
tree=$1 W=$2 E=$3; d=$W/decoy-head
export FM_HOME=$d FM_ROOT=$d FM_ROOT_OVERRIDE=$d FM_STATE_OVERRIDE=$d/state FM_DATA_OVERRIDE=$d/data \
  FM_CONFIG_OVERRIDE=$d/config FM_PROJECTS_OVERRIDE=$d/projects FM_BACKEND=herdr TERM_PROGRAM=herdr
unset FM_GATE_REFUSE_BYPASS NO_MISTAKES_GATE
cd "$tree"; out=$E/hosted-extra.txt; : > "$out"
bin/fm-test-run.sh tests/fm-backend.test.sh tests/fm-control.test.sh tests/fm-teardown.test.sh > "$E/hosted-runner.log" 2>&1
echo "$? bin/fm-test-run.sh (3 suites, leaked launcher env)" >> "$out"
unshare -U -r -p -f --mount-proc --kill-child bash tests/fm-session-lock-ancestry.test.sh > "$E/hosted-lock-pidns.log" 2>&1
echo "$? fm-session-lock-ancestry (leaked env, private PID namespace)" >> "$out"
touch "$W/done-extra"
