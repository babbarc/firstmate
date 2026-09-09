# Gitea pull request watch and merge verification

Empirical record for the merge watch and the merge path on Gitea (which also covers API-compatible Forgejo), alongside the GitHub and GitLab ones.
The arming, poll, missing-CLI, and merge-refusal evidence was collected live on 2026-09-09 against the fleet's own `alps:3222` instance.
The full path was also proven across the server-ops merge runs #21-#39 (2026-09-06..09) and the joy-brain runs #1-#7, with the fleet-verified quirks first recorded in this home's learnings on 2026-09-06..07.
Every output is reproduced exactly.

## Versions

```
$ tea --version
Version: 0.14.0	golang: 1.26.5	built with: nixpkgs	go-sdk: 0.23.2

$ jq --version
jq-1.8.2

$ bash --version | head -1
GNU bash, version 5.3.15(1)-release (x86_64-pc-linux-gnu)
```

## The evidence project

All live evidence here reads <http://alps:3222/babbarc/server-ops>, a private Gitea project on the fleet's own instance.
It holds two deliberately merged pull requests, #38 and #39, so the merged outcome can be shown against real data.
No open pull request exists on the project: the next index, #40, returns not found, so the open-state evidence comes from the live refusal runs and from the `tests/fm-pr-merge.test.sh` fixtures rather than from a live open pull request.

Reading any pull request needs the `tea` login `firstmate-alps-3222`, a Gitea login for user `babbarc` whose token lives in `~/.config/tea/config.yml`.
The instance base URL `http://alps:3222` is allow-listed in this home's `config/gitea-instances`, which is what makes arming or merging against it legal.

A non-default instance appears below only as the placeholder `http://gitea.example:3222`, which resolves nowhere.
That is deliberate: the host-agnostic property is a property of the stored record and the poll's URL reconstruction, so it is demonstrated by inspecting those and by the arming refusals rather than by reaching any private instance.

## Why the host is data rather than a constant

Gitea runs almost entirely on self-hosted instances, so a pull request can live under any base URL.
That base URL has no fixed domain, no guaranteed TLS, and often a non-default port, so the stored record carries `provider`, `url`, `host`, `path`, and `number`, where `host` is the whole instance base URL - scheme, host, and port - rather than a bare DNS name.
`path` is `owner/repository`, exactly like GitHub and unlike GitLab's arbitrary-depth namespace.
Every consumer rebuilds the URL from those parts and refuses any record that does not reconstruct the stored URL exactly.
`tests/fm-pr-check-security.test.sh` proves the host-agnostic sidecar path through a non-default-host record and verifies that `tea` receives the reconstructed repository and login.

Because a Gitea URL admits a plain-`http://` origin, `fm_pr_url_parse` checks only the URL shape.
The arming and merge paths additionally require the base URL to match a line in the local `config/gitea-instances` allow-list before any side effect, which is what makes accepting that shape safe.
The placeholder host is refused there rather than armed:

```
$ fm-pr-check.sh e4 http://gitea.example:3222/org/repo/pulls/1
error: http://gitea.example:3222 is not an allow-listed Gitea instance; add its base URL to /tmp/fm-gitea-evidence/config/gitea-instances
$ echo $?
1
```

## How tea is invoked, and why

A Gitea pull request is addressed through `tea` by the owner, repository, and login derived from the instance base URL.
The login name is `firstmate-<host>-<port>` - the host with `.` replaced by `-`, and the explicit port or, when the base URL omits one, the scheme default (443 for https, 80 for http).
`http://alps:3222` therefore derives the login `firstmate-alps-3222`:

```
$ tea login list -o csv
Name,URL,SSHHost,User,Default
firstmate-alps-3222,http://alps:3222,alps:3222,babbarc,false
```

The login name is never stored in the sidecar.
The arming path and the byte-static poll both re-derive it from the same base URL, so the poll needs no config read and no extra per-task artifact.

The poll keys on the top-level `merged` boolean, and `tea`'s own `pulls <n>` view does not expose it - that view's JSON names the field `hasMerged`.
The poll and merge therefore read the pull request through `tea api` with the derived login, which returns Gitea's raw JSON with the top-level `merged` boolean, and `jq` reads only that top-level boolean so a nested `merged: true` elsewhere in a compatible response can never false-positive:

```
$ tea api --login firstmate-alps-3222 repos/babbarc/server-ops/pulls/39 \
    | jq '{number, state, merged, mergeable, head: .head.sha, merged_at, merge_commit_sha}'
{
  "number": 39,
  "state": "closed",
  "merged": true,
  "mergeable": true,
  "head": "5100c06ef1a7cda0797a61fa6c0c8c96f3057c09",
  "merged_at": "2026-09-09T16:28:59+01:00",
  "merge_commit_sha": "a071e943e9266428ac639ce83bd256b315be26ce"
}
```

The raw REST single-pull-request path is not a substitute: on this private instance a request without the authenticated login returns a bare "not found" swagger pointer rather than the pull request.

```
$ curl -s -w '\nHTTP %{http_code}\n' http://alps:3222/api/v1/repos/babbarc/server-ops/pulls/39
{"message":"not found","url":"http://alps:3222/api/swagger"}
HTTP 404
```

That is why the poll and merge read through `tea api` with the derived login instead of reconstructing a raw REST URL: the authenticated path is the one that returns the pull request, and an unauthenticated one stays a "not found" stub that would otherwise be indistinguishable from an unmerged pull request.

## End to end: arming and polling a real pull request

Two tasks were armed, both against the merged fixture:

```
$ fm-pr-check.sh e1 http://alps:3222/babbarc/server-ops/pulls/39
armed: state/e1.check.sh
$ fm-pr-check.sh e2 http://alps:3222/babbarc/server-ops/pulls/38
armed: state/e2.check.sh
```

The stored record for `e1`, showing the provider tag and the whole instance base URL as data:

```
$ cat state/e1.pr-poll
gitea
http://alps:3222/babbarc/server-ops/pulls/39
http://alps:3222
babbarc/server-ops
39
```

The provenance record for `e1`, showing the bumped version tag, the provider tag, and - in the last four lines - the two content hashes and the two file identities:

```
$ cat state/e1.pr-poll-registration
fm-pr-poll-registration-v2
e1
gitea
http://alps:3222/babbarc/server-ops/pulls/39
http://alps:3222
babbarc/server-ops
39
745406c4be4f74588d2a33324801e06300caefa1fd7571dae6d8d5da72b39d1a
6944b31f18bf1f3035e12c4ffeefd8e407280ab64878a73f64762879173ddbd5
50:378753
50:378754
```

Arming also records the head commit, read through `tea api` and `jq`:

```
$ grep -E '^pr(_head)?=' state/e1.meta
pr=http://alps:3222/babbarc/server-ops/pulls/39
pr_head=5100c06ef1a7cda0797a61fa6c0c8c96f3057c09
```

Running each published poll the way the watcher does, where an empty result means the poll stayed silent and produced no wake:

```
$ fm-pr-poll.sh --validated $(tr '\n' ' ' < state/e1.pr-poll)
merged
$ fm-pr-poll.sh --validated $(tr '\n' ' ' < state/e2.pr-poll)
merged
```

The same bytes work in the watcher's sidecar-driven mode, where the published check locates its own record.
The check is published mode `0600`, so the watcher runs it with `bash` rather than executing it:

```
$ bash state/e1.check.sh
merged
```

## A missing CLI produces no wake, never a false merge

The poll is silent on every error by design, so a missing `tea` or `jq` would otherwise be indistinguishable from a pull request that is never merged.
With either removed from `PATH`, the poll stays silent even for the pull request that is genuinely merged:

```
$ PATH="$notea" fm-pr-poll.sh --validated $(tr '\n' ' ' < state/e1.pr-poll)
$ PATH="$nojq" fm-pr-poll.sh --validated $(tr '\n' ' ' < state/e1.pr-poll)
```

Arming is the one point where that can be reported, so it refuses there instead of arming a watch that can never fire.
The Gitea poll reads the merged state out of `tea`'s raw API JSON, so it needs `jq` the way the GitLab poll does not, and both are checked together:

```
$ PATH="$notea" fm-pr-check.sh e5 http://alps:3222/babbarc/server-ops/pulls/39
error: watching a Gitea pull request requires tea on PATH
$ echo $?
1
$ PATH="$nojq" fm-pr-check.sh e6 http://alps:3222/babbarc/server-ops/pulls/39
error: watching a Gitea pull request requires jq on PATH
$ echo $?
1
```

A watch whose derived login is not configured is refused at arming too, rather than armed to never fire:

```
$ fm-pr-check.sh e8 http://gitea.example:3222/org/repo/pulls/1
error: watching a Gitea pull request needs a tea login named 'firstmate-gitea-example-3222' for http://gitea.example:3222 (run: tea login add --name firstmate-gitea-example-3222 --url http://gitea.example:3222 --token <token>)
$ echo $?
1
```

## Registration version

The live registration tag is `fm-pr-poll-registration-v2`, the same bumped tag as GitLab, which includes the provider tag.
A `fm-pr-poll-registration-v1` record no longer parses.
Arm a current watch with `bin/fm-pr-check.sh`.

## Merging a pull request

`bin/fm-pr-merge.sh` merges a Gitea pull request through the shared recording helper and Gitea's own live pre-merge guards.
Every run below used a throwaway `FM_HOME`, so no live task record was touched.
The fixture pull requests are already merged, so the live merge itself was never reached - `tea pr merge` has no dry run, and a live success path would mean merging someone's work to produce evidence.

Merging needs `tea` for the read and `jq` to parse it, and either one absent refuses before anything is recorded:

```
$ PATH="$notea" fm-pr-merge.sh e5 http://alps:3222/babbarc/server-ops/pulls/39
error: merging a Gitea pull request requires tea on PATH
$ echo $?
1
$ PATH="$nojq" fm-pr-merge.sh e6 http://alps:3222/babbarc/server-ops/pulls/39
error: merging a Gitea pull request requires jq on PATH
$ echo $?
1
```

Neither refusal armed a poll or recorded a `pr=`, so a missing tool leaves no half-prepared merge behind.

The pre-merge check reads one live view of the pull request and refuses unless it is open, not already merged, and mergeable, reporting every failing condition rather than just the first.
An already-merged pull request is refused on its state and its merged flag - Gitea keeps `mergeable` as `true` after a merge, so that condition alone is not what refuses it:

```
$ fm-pr-merge.sh e3 http://alps:3222/babbarc/server-ops/pulls/39
armed: state/e3.check.sh
error: refusing to merge http://alps:3222/babbarc/server-ops/pulls/39
  - state is "closed", not open
  - the pull request is already merged (merged="true")
$ echo $?
1
```

The refusal came after `pr=` was recorded and the merge poll was armed, exactly as a failing merge does on the GitHub side, so a refusal still leaves the audit trail and the watch in place.

A recorded `pr_head=` that no longer matches the live head is reported, and the live head is what gets verified.
The stale value below was written into the task record by hand, because a Gitea arming always records the real head on its own:

```
$ fm-pr-merge.sh e9 http://alps:3222/babbarc/server-ops/pulls/39
armed: state/e9.check.sh
notice: recorded head 1111111111111111111111111111111111111111 disagrees with the live head 5100c06ef1a7cda0797a61fa6c0c8c96f3057c09; tea cannot bind the merge to a head, so this verifies the live view only
error: refusing to merge http://alps:3222/babbarc/server-ops/pulls/39
  - state is "closed", not open
  - the pull request is already merged (merged="true")
```

The `mergeable="false"` refusal condition, the successful merge, the unconfirmed-merge refusal, and the unreadable-outcome path are covered by `tests/fm-pr-merge.test.sh` against a tea fixture, because no open pull request exists on the live project to exercise them against.
The merge itself runs through `tea pr merge --repo <owner>/<repo> --login <login> --style squash`, defaulting to squash the way the GitHub path does, and after `tea` returns success Gitea's live state is read back and accepted only when the pull request reads `merged`.
An outcome that cannot be positively confirmed leaves the poll armed and records no landed result.

## Why the head is read live, and why the merge cannot bind it

The Gitea pre-merge read requires the live `head.sha` to be a valid commit, and reports a recorded `pr_head` that disagrees with it.
Unlike the GitLab path, `tea pr merge` exposes no head-commit binding - there is no `--sha` equivalent - so the Gitea path matches the GitHub model rather than the GitLab one.
The live head is still read and verified because the open/mergeable conditions must be judged against a known commit, but the merge itself is not bound to it.
A push landing between the read and the merge is a race this provider path cannot close by itself, which is why the post-merge readback is the confirmation rather than the head binding.

## Why a recorded head is not the authority

`bin/fm-pr-check.sh` records `pr_head=` for Gitea, where `tea api` plus `jq` can read `head.sha`, which is one place Gitea differs from GitLab.
It is still optional by design, and the other consumers already treat it that way: `bin/fm-teardown.sh` reads the head from the forge at teardown and falls back to its provider-agnostic content check, and `bin/fm-review-diff.sh` resolves the head from the remote when none is recorded.

The merge path deliberately does not depend on a recorded head.
A rebase moves the head and leaves any recorded value stale, so a merge decided from metadata can verify a commit that no longer exists.
Reading the head live at merge time and reporting a recorded value that disagrees is what closes that gap; on Gitea the verified head cannot be passed to the merge, so the disagreement is reported rather than made binding.

## Known Gitea quirks

Three quirks around the merge path were recorded in this home's learnings on 2026-09-06 and re-confirmed during the server-ops runs:

- `tea pr merge <n>` can fail once right after a preceding merge lands ("failed to merge PR, is it still open?"), because Gitea has not recomputed mergeability yet; a single retry goes through.
- `tea pr create` needs the `read:issue` scope, which the `babbarc` token lacks, so pull request creation goes through the Gitea API instead; that is separate from the merge watch and outside this record's scope.
- `fm-pr-merge.sh` output that ends at the `verified: <url> is open and mergeable at head <sha>` line when a terminal is tail-clipped mid-run is not a failure; that line precedes the merge and the readback, so confirm the outcome with `tea pr list --repo <owner>/<repo> --state all` rather than reading a truncated pane.
