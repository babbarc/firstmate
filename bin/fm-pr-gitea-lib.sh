#!/usr/bin/env bash
# fm-pr-gitea-lib.sh - fleet patch: the Gitea/Forgejo instance allow-list, tea
# login derivation, and pull request forge read.
#
# bin/fm-pr-lib.sh owns the Gitea URL shape (fm_pr_url_parse). Because that
# shape admits a plain-http origin, every path that acts on an instance first
# requires its base URL to match a line in the local config/gitea-instances
# allow-list; this file owns that allow-list read and the tea reads built on it.
# bin/fm-pr-check.sh and bin/fm-pr-merge.sh source it. bin/fm-teardown.sh and
# bin/fm-backlog-transition-lib.sh run it as a command instead of sourcing it,
# so these helpers stay out of teardown's source graph, which already sits near
# the per-root ShellCheck memory cap in bin/fm-lint.sh.
#
# Usage when executed:
#   bash fm-pr-gitea-lib.sh instance-allowed <config-dir> <base-url>
#     exit 0 when <base-url> is an allow-listed instance, 1 otherwise
#   bash fm-pr-gitea-lib.sh pr-view <config-dir> <pr-url>
#     print "<state>\t<head-sha>\t<html-url>" for an allow-listed Gitea pull
#     request, where state is "merged" or Gitea's own state; exit 1 when the
#     URL is not such a pull request, tea or jq is missing, or the read fails

if ! declare -F fm_pr_url_parse >/dev/null 2>&1; then
  # shellcheck source=bin/fm-pr-lib.sh disable=SC1091
  . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fm-pr-lib.sh"
fi

# Set by fm_pr_gitea_instance_resolve; read by the sourcing caller.
FM_PR_GITEA_LOGIN=

# A Gitea instance base URL: http:// or https://, then a valid authority, and
# nothing else - no path, no query, no trailing slash.
fm_pr_gitea_base_url_valid() {  # <base-url>
  local url=${1-} rest
  local LC_ALL=C
  case "$url" in
    http://*) rest=${url#http://} ;;
    https://*) rest=${url#https://} ;;
    *) return 1 ;;
  esac
  case "$rest" in
    */*|'') return 1 ;;
  esac
  fm_pr_gitea_authority_valid "$rest"
}

# The tea login name firstmate uses for a Gitea instance, derived from the
# instance base URL as "firstmate-<host>-<port>" (host with "." replaced by
# "-"). The port is always part of the identity - the explicit port when the
# base URL carries one, otherwise the scheme default (443 for https, 80 for
# http) - so two allow-listed instances on the same host but different ports,
# or the same host:port under different schemes, never collide on one login
# name. Both the arming paths and the byte-static poll derive it the same way
# from the same base URL, so no login name is ever stored - the poll needs no
# config read and no extra per-task artifact to know which tea login to use.
fm_pr_gitea_derive_login() {  # <base-url>
  local url=${1-} scheme authority host port
  local LC_ALL=C
  case "$url" in
    http://*) scheme=http; authority=${url#http://} ;;
    https://*) scheme=https; authority=${url#https://} ;;
    *) return 1 ;;
  esac
  case "$authority" in
    */*|'') return 1 ;;
    *:*) host=${authority%:*}; port=${authority##*:} ;;
    *) host=$authority; port= ;;
  esac
  case "$host" in
    ''|*[!a-z0-9.-]*) return 1 ;;
  esac
  if [ -z "$port" ]; then
    case "$scheme" in https) port=443 ;; *) port=80 ;; esac
  fi
  case "$port" in ''|*[!0-9]*) return 1 ;; esac
  printf 'firstmate-%s-%s\n' "${host//./-}" "$port"
}

# Read config/gitea-instances and, when <base-url> matches a configured line's
# first field exactly, set FM_PR_GITEA_LOGIN to the derived tea login name and
# return 0. Return non-zero when the file is absent, unreadable, or has no
# matching line. A line is one instance base URL, optionally followed by
# whitespace and the tea login name; when present that second field is only
# accepted when it equals the derived "firstmate-<host>-<port>", because the
# byte-static poll always re-derives the login rather than reading this file,
# so a divergent name would arm a watch that silently never fires. Blank lines
# and lines whose first non-blank character is "#" are ignored. This is the
# instance allow-list the arming paths consult before any side effect.
fm_pr_gitea_instance_resolve() {  # <config-dir> <base-url>
  local config_dir=${1-} base_url=${2-} file line rest url named login
  local LC_ALL=C
  FM_PR_GITEA_LOGIN=
  [ -n "$config_dir" ] && [ -n "$base_url" ] || return 1
  file="$config_dir/gitea-instances"
  [ -f "$file" ] && [ ! -L "$file" ] && [ -r "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|[[:space:]]*'#'*|'#'*) continue ;;
    esac
    # Trim surrounding whitespace, then split off an optional second field.
    rest=${line#"${line%%[![:space:]]*}"}
    rest=${rest%"${rest##*[![:space:]]}"}
    url=${rest%%[[:space:]]*}
    named=${rest#"$url"}
    named=${named#"${named%%[![:space:]]*}"}
    named=${named%%[[:space:]]*}
    [ "$url" = "$base_url" ] || continue
    fm_pr_gitea_base_url_valid "$url" || return 1
    login=$(fm_pr_gitea_derive_login "$url") || return 1
    case "$login" in
      ''|*[!A-Za-z0-9._-]*) return 1 ;;
    esac
    [ -z "$named" ] || [ "$named" = "$login" ] || return 1
    FM_PR_GITEA_LOGIN=$login
    return 0
  done < "$file"
  return 1
}

# One live view of a Gitea pull request through tea api, printed as
# "<state>\t<head-sha>\t<html-url>". The state is "merged" for a merged pull
# request and Gitea's own state otherwise; a response without a boolean
# "merged" and a string head sha prints nothing and fails.
fm_pr_gitea_pr_view() {  # <tea-login> <owner> <repo> <number>
  local view
  command -v tea >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1
  view=$(tea api --login "$1" "repos/$2/$3/pulls/$4" 2>/dev/null \
    | jq -r 'if type == "object" and (.merged | type == "boolean") and (.head.sha | type == "string")
             then (if .merged then "merged" else ((.state // "") | tostring) end) + "\t" + .head.sha + "\t" + ((.html_url // "") | tostring)
             else empty end' 2>/dev/null) || return 1
  [ -n "$view" ] || return 1
  printf '%s\n' "$view"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "$#:${1-}" in
    3:instance-allowed)
      fm_pr_gitea_instance_resolve "$2" "$3"
      exit
      ;;
    3:pr-view)
      fm_pr_url_parse "$3" && [ "$FM_PR_PROVIDER" = gitea ] || exit 1
      fm_pr_gitea_instance_resolve "$2" "$FM_PR_HOST" || exit 1
      fm_pr_gitea_pr_view "$FM_PR_GITEA_LOGIN" "$FM_PR_OWNER" "$FM_PR_REPO" "$FM_PR_NUMBER"
      exit
      ;;
  esac
  echo "usage: fm-pr-gitea-lib.sh instance-allowed <config-dir> <base-url> | pr-view <config-dir> <pr-url>" >&2
  exit 2
fi
