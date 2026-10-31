#!/usr/bin/env bash
# Runs the suites that source an interactive shell in the pane's FOREGROUND process
# group: a coreutils `timeout` wrapper or `&` job would stop them with SIGTTOU/SIGTTIN.
W=/tmp/fm-envleak.WVuo8d E=/home/yeti/.no-mistakes/evidence/01M692TMTH565CKS4F27530D94
cd /home/yeti/.no-mistakes/worktrees/b2ec250c52f2/01M692TMTH565CKS4F27530D94
d=$W/decoy-head
export FM_HOME=$d FM_ROOT=$d FM_ROOT_OVERRIDE=$d FM_STATE_OVERRIDE=$d/state FM_DATA_OVERRIDE=$d/data \
  FM_CONFIG_OVERRIDE=$d/config FM_PROJECTS_OVERRIDE=$d/projects FM_BACKEND=herdr TERM_PROGRAM=herdr
unset FM_GATE_REFUSE_BYPASS
: > "$E/final-hosted-fg.txt"
for s in fm-spawn-orca-worktree fm-spawn-dispatch-profile; do
  t0=$SECONDS
  bash tests/$s.test.sh > "$E/final-hosted-fg-$s.log" 2>&1
  rc=$?
  echo "$rc $((SECONDS-t0))s $s" >> "$E/final-hosted-fg.txt"
done
touch "$E/final-hosted-fg.done"
