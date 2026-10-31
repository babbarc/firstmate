#!/usr/bin/env bash
# Runs suites from inside a real Herdr lab pane as a supervisor shell would.
# usage: hosted-run.sh <tree> <label> <workdir> <evidence>
tree=$1 label=$2 W=$3 E=$4
decoy=$W/decoy-$label; mkdir -p "$decoy/config" "$decoy/state" "$decoy/data" "$decoy/projects"
export FM_HOME=$decoy FM_ROOT=$decoy FM_ROOT_OVERRIDE=$decoy FM_STATE_OVERRIDE=$decoy/state FM_DATA_OVERRIDE=$decoy/data \
  FM_CONFIG_OVERRIDE=$decoy/config FM_PROJECTS_OVERRIDE=$decoy/projects FM_BACKEND=herdr TERM_PROGRAM=herdr
unset FM_GATE_REFUSE_BYPASS
env | grep -E '^(HERDR_|TERM_PROGRAM=|FM_(HOME|BACKEND|STATE_OVERRIDE)=)' | sed "s#$W#\$W#g" > "$E/launcher-env-$label.txt"
cd "$tree"
mkdir -p "$W/logs-$label"
ls tests | grep -E '^fm-(spawn|backend|teardown|recover|control|session|home|task).*test.sh' | grep -vE 'e2e|smoke|live' | xargs -I{} sh -c 'grep -q "lib.sh" tests/{} && echo {}' > "$W/suites"
export W label
xargs -P 6 -I{} bash -c 'timeout -k 5 400 bash tests/{} > "$W/logs-$label/{}.log" 2>&1; echo "$? {}"' < "$W/suites" | sort -k2 > "$E/suite-results-$label.txt"
touch "$W/done-$label"
