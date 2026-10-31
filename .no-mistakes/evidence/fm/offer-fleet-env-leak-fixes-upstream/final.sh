#!/usr/bin/env bash
# usage: final.sh <label: clean|hosted> ; one line per suite: <rc> <seconds> <suite>
label=$1 W=/tmp/fm-envleak.WVuo8d E=/home/yeti/.no-mistakes/evidence/01M692TMTH565CKS4F27530D94
cd /home/yeti/.no-mistakes/worktrees/b2ec250c52f2/01M692TMTH565CKS4F27530D94
if [ "$label" = hosted ]; then
  d=$W/decoy-head
  export FM_HOME=$d FM_ROOT=$d FM_ROOT_OVERRIDE=$d FM_STATE_OVERRIDE=$d/state FM_DATA_OVERRIDE=$d/data \
    FM_CONFIG_OVERRIDE=$d/config FM_PROJECTS_OVERRIDE=$d/projects FM_BACKEND=herdr TERM_PROGRAM=herdr
fi
unset FM_GATE_REFUSE_BYPASS
: > "$E/final-$label.txt"
run() {
  s=$1 t0=$SECONDS
  timeout -k 5 1200 bash tests/$s.test.sh > "$E/final-$label-$s.log" 2>&1
  rc=$?
  echo "$rc $((SECONDS-t0))s $s" >> "$E/final-$label.txt"
}
for s in fm-test-fixtures fm-session-lock-ancestry fm-spawn-dispatch-profile fm-spawn-orca-worktree; do run $s & done
wait
touch "$E/final-$label.done"
