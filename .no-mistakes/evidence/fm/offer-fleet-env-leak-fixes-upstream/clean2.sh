#!/usr/bin/env bash
W=/tmp/fm-envleak.WVuo8d E=/home/yeti/.no-mistakes/evidence/01M692TMTH565CKS4F27530D94
cd /home/yeti/.no-mistakes/worktrees/b2ec250c52f2/01M692TMTH565CKS4F27530D94
unset NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS FM_HOME FM_BACKEND
: > "$E/final-clean2.txt"
# orca without nohup: SIGHUP must stay deliverable for its consume/HUP case
( timeout -k 5 1200 bash tests/fm-spawn-orca-worktree.test.sh > "$E/final-clean2-orca.log" 2>&1; echo "$? fm-spawn-orca-worktree (clean, HUP deliverable)" >> "$E/final-clean2.txt" ) &
# lock-ancestry where init really adopts orphans: a private PID namespace
( unshare -U -r -p -f --mount-proc --kill-child bash -c 'bash tests/fm-session-lock-ancestry.test.sh' > "$E/final-clean2-lock-pidns.log" 2>&1; echo "$? fm-session-lock-ancestry (clean, PID-1 init)" >> "$E/final-clean2.txt" ) &
# same, with the launcher env leaked
d=$W/decoy-head
( env HERDR_ENV=1 HERDR_PANE_ID=w1:p1 HERDR_TAB_ID=w1:t1 HERDR_WORKSPACE_ID=w1 HERDR_SESSION=fm-lab-envleak-1472549-2028 \
  HERDR_SOCKET_PATH=/home/yeti/.config/herdr/sessions/fm-lab-envleak-1472549-2028/herdr.sock HERDR_BIN_PATH=/home/yeti/.local/bin/herdr \
  TERM_PROGRAM=herdr FM_BACKEND=herdr FM_HOME=$d FM_ROOT=$d FM_ROOT_OVERRIDE=$d FM_STATE_OVERRIDE=$d/state FM_DATA_OVERRIDE=$d/data \
  FM_CONFIG_OVERRIDE=$d/config FM_PROJECTS_OVERRIDE=$d/projects \
  unshare -U -r -p -f --mount-proc --kill-child bash -c 'bash tests/fm-session-lock-ancestry.test.sh' > "$E/final-leak-lock-pidns.log" 2>&1; echo "$? fm-session-lock-ancestry (leaked launcher env, PID-1 init)" >> "$E/final-clean2.txt" ) &
# pre-fix lib, clean env: same failure proves it predates this change
( cd $W/base && bash tests/fm-session-lock-ancestry.test.sh > "$E/final-base-clean-lock.log" 2>&1; echo "$? fm-session-lock-ancestry (clean, pre-fix tests/lib.sh)" >> "$E/final-clean2.txt" ) &
wait
touch "$E/final-clean2.done"
