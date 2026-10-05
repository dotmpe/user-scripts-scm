#!/bin/bash
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
us_gh_pre=User-Script.GitHub.CLI
us_gh_man='Building some TSV.

Case scenarios:
  - Fetch repo lists/details, add tag (locally) per repo
  - Auto-generated suggestions for tag value or changes
  - Batch-apply (add/remove metadata or set status) based on attributes
  - Track description and other project feature settings in TSV as well
  - Apply all local updates back to GH in batches or from selected, filtered
    sets

Supported features:
  - Fetch repolist, run interactive tag edit/auto-fill loop
  - Simple grep on tag, TSV fields
  - Apply simple repo settings

TODO: fix all descriptions
TODO: find destination for tag value, aside of cached TSV/Bash files

NOTE: JSON/Jq pipelines are very flexible to script, but so ideal for user data
oriented loops. May want to keep local storage cache in JSON still.

NOTE: There are many possible input options here, but do not want extensive CLI
parsing here yet without better rudimentary toolkit. (Just use env for inputs.)

NB: field values must not be empty: Bash read collapses empty columns'
us_gh_var=(
  US_GH_DOMAIN
)
us_gh_fun=(
  .apply-repo-settings
  .fetch-repolist-details.tsv
  .fetch-repolist.tsv
  .list-repos
  .list-repos.tsv
  .tag-repolist

  #.tag-repo
  #.archive-repos
  .workflow-status{,.grep}
)
declare -gA \
us_gh_hooks=(
  [declare]='
  : env "${US_GH_CONFIG:=.local/etc/us_gh_repos_conf.bash}"
  : env "${US_GH_OWNERS:=${SCM_DOMAIN:-${DOMAIN:?}}}"
  : env "${US_GH_STATE_DIRTY:=.local/cache/gh-repos-state-dirty.bash}"
  : env "${US_GH_REPOS_OWNER_TSV:=${HOME:?}/.local/var/gh-repos-owner.tab}"
  : env "${US_GH_REPOS_OWNER_DETAILS_TSV:=${HOME:?}/.local/var/gh-repos-owner-details.tab}"
'

  [init]='
  declare -gA us_gh_dirty
  us_gh_repos_ownertab=(
    owner name tag defbr stars forks isfrk isarch istpl ispriv plang haswiki issuecnt
  )
  us_gh_repos_ownerattr=(
    nameWithOwner defaultBranchRef
    stargazerCount forkCount
    primaryLanguage
    is{Fork,Archived,Template,Private}
    hasWikiEnabled
    issues
  )

  us_gh_repos_ownerdetailtab=(
    owner name description diskuse created updated pushed
  )
  us_gh_repos_ownerdetailattr=(
    nameWithOwner
    description
    createdAt updatedAt pushedAt
    diskUsage
  )

  us_gh_runs_state_attr=(
    conclusion
    createdAt
    databaseId
    displayTitle
    event
    headBranch
    headSha
    name
    number
    startedAt
    status
    updatedAt
    url
    workflowDatabaseId
    workflowName
  )
  #us_gh_runs_state_tab

  :cache-load "$US_GH_CONFIG"
')

User-Script.GitHub.CLI.fetch-repolist-details.tsv() {
  ! (($#)) || return ${_E_GAE:?}
: input "${US_GH_REPOS_OWNER_DETAILS_TSV:?}"
  local repotab=$_

  [[ -s "${repotab:?}" ]] &&
    :to-v wc ${repotab:?} && return

  ${us_gh_pre:?}list-repos.tsv "${repotab:?}" \
    "$(IFS=,; echo "${us_gh_repos_ownerdetailattr[*]:?}")" '[
        (.nameWithOwner | split("/")[0]),
        (.nameWithOwner | split("/")[1]),
        .description,
        .diskUsage,
        .createdAt, .updatedAt, .pushedAt
    ]' &&
  :to-v wc ${repotab:?}
}

User-Script.GitHub.CLI.fetch-repolist.tsv() {
: about 'Make repos table for tagging'
: param '~ ...'
  ! (($#)) || return ${_E_GAE:?}
: input "${US_GH_REPOS_OWNER_TSV:?}"
  local repotab=$_

  [[ -s "${repotab:?}" ]] &&
    :to-v wc ${repotab:?} && return

  printf -v header '#TSV: %s' "${us_gh_repos_ownertab[*]}" &&
  ${us_gh_pre:?}list-repos.tsv "${repotab:?}" \
    "$(IFS=,; echo "${us_gh_repos_ownerattr[*]:?}")" '[
             (.nameWithOwner | split("/")[0]),
             (.nameWithOwner | split("/")[1]),
             " ",
             if (.defaultBranchRef.name? // "") == "" then "-" else
               .defaultBranchRef.name end,
             .stargazerCount, .forkCount,
             .isFork, .isArchived, .isTemplate, .isPrivate,
             .primaryLanguage.name? // "-",
             .hasWikiEnabled,
             .issues.totalCount ]' "$header" &&
  :to-v wc ${repotab:?}
}

User-Script.GitHub.CLI.list-repos() {
: about 'Fetch new list with attributes'
: param '~ <Attribute-selection> [<Owners>] [<Limit-rows-override>] ...'
: input "${1?$(:argv-err 1 'JSON fields selector')}"
  local attrsel=${1} owners limit
  owners=${2:-${US_GH_OWNERS:?}}
  limit=${3:-${US_GH_REPO_LIMIT:-100}}

  # NOTE: without owner, empty repos (and others perhaps) would not be listed
  for owner in ${owners:?}; do
    gh repo list "${owner:?}" --json "$attrsel" --limit "$limit" || return
  done
}

User-Script.GitHub.CLI.list-repos.tsv() {
: about 'Fetch new list with attributes, and process to table'
: param '~ <Output-file> <Attribute-selection> <Jq-transform> [<TSV-header>] [<TSV-footer>] ...'
: input "${1?$(:argv-err 1 'Output file')}"
: input "${2?$(:argv-err 1 'JSON fields selector')}"
: input "${3?$(:argv-err 1 'Jq transform')}"
  local header=${4:-} footer=${5-}

  [[ ${5+set} ]] ||
    printf -v footer '# Generated at %s' "$(date --iso=sec)"

  {
    [[ ! ${header:+ne} ]] || printf '%s\n' "$header"
    ${us_gh_pre:?}list-repos "${2}" | jq -r '.[] | '"${3}"' | @tsv'
    [[ ! ${footer:+ne} ]] || printf '%s\n' "$footer"
  } >> "${1}"
}

User-Script.GitHub.CLI.grep-repolist() {
: about 'Edit tag for repositories'
: input "${US_GH_REPOS_OWNER_TSV:?}"
  local repotab=$_ act=${1:---tag} fs=${IFS:1:1}

  case "${act:?}" in
  ( --owner ) grep "^$2"$'[\t]' "$repotab" ;;
  ( --column )
      local column=${2:?} pattern=${3:?} _grep
      :grep-tabcolumn.extended "$column" "$pattern" _grep &&
      \builtin command grep -E "$_grep" "$repotab" "${@:4}"
    ;;
  ( --tag )     \builtin command grep "[[:space:]]$2[[:space:]]" "$repotab" ;;
  esac
}

User-Script.GitHub.CLI.tag-repolist() {
: about 'Edit tag for repositories'
  ! (($#)) || return ${_E_GAE:?}
  . <(:funbody ${FUNCNAME}._local)

: env "${autotag:=1}"
: env "${autoaddtag:=0}"

  exec {tsv_fd}< "$repotab" &&
  while IFS=$'\t\n' read -u ${tsv_fd} -ra values; do
    ((row+=1))
    printf '%i. ' $row
    IFS=$'\t'; echo "${values[*]}"; IFS=$' \t\n'
    if ((autoaddtag)) || ((autotag)) && [[ ${tag:- } == ' ' ]]; then
      . <(:funbody ${FUNCNAME}._taguggestions)
    fi
    :read-tty "  Tags: " "${tag_upd:-$tag}" tag_upd || { stat=$?
      (( stat != 130 )) || stat=
      break
    }
    [[ "${tag_upd:- }" = "${tag}" ]] || dirty=1
  done < "${repotab:?}" && IFS=$' \t\n' && exec {tsv_fd}<&- ||
    :restore-ifs :failerr 'Error reading repolist' || return

  if ((dirty)); then
    say.v "Writing state to disk for ${#us_gh_dirty[*]} entries..."
    # XXX: format this on lines for readabilty may be, but key are not long and
    # values (tag) are fairly diverse and not too repetitive atm.
    declare -p us_gh_dirty >"${US_GH_STATE_DIRTY:?}"
  fi

  return ${stat-}
}

User-Script.GitHub.CLI.tag-repolist._local() {
: input "${US_GH_REPOS_OWNER_TSV:?}"
  local repotab=$_
  local -n _fields=us_gh_repos_ownertab
  local values "${_fields[@]}"  tsv_fd  stat dirty=0 row=0
  local -n owner='values[0]' name='values[1]' tag='values[2]' \
    defbr='values[3]' \
    stars='values[3]' \
    forks='values[4]' \
    isfrk='values[6]' \
    isarch='values[7]' \
    istpl='values[8]' \
    ispriv='values[9]' \
    plang='values[10]' \
    haswiki='values[11]' \
    issuecnt='values[12]' \
    tag_upd='us_gh_dirty["$owner.$name.tag"]'

  ! test -s "${US_GH_STATE_DIRTY:?}" || \builtin . "$_" || return
}

User-Script.GitHub.CLI.tag-repolist._taguggestions() {

  [[ ${isfrk-} != true ]] || :word-append @forks tag_upd
  [[ ${ispriv-} != true ]] || :word-append @private tag_upd
  [[ ${isarch-} != true ]] || :word-append @archived tag_upd
  [[ ${istpl-} != true ]] || :word-append @templates tag_upd
}

User-Script.GitHub.CLI.tag-repolist.sync() {
: about 'Write back user updated fields (from "dirty" Bash array) to TSV file'
  ! (($#)) || return ${_E_GAE:?}
  . <(:funbody ${FUNCNAME%.sync}._local)
: input "${us_gh_dirty[*]:?}" # Do not run with empty input

  exec {tsv_fd}< "$repotab" &&
  while IFS=$'\t\n' read -u ${tsv_fd} -ra values; do
    if [[ "${tag_upd:- }" != "${tag:- }" ]]; then
      tag=${tag_upd:?}
    else
      tag=${tag:- }
    fi
    IFS=$'\t'; echo "${values[*]}"; IFS=$' \t\n'
  done <"${repotab:?}" >"${repotab}.new" && IFS=$' \t\n' && exec {tsv_fd}<&- ||
    :restore-ifs :failerr 'Error reading repolist' || return

  cp "${repotab}"{,.bup} &&
  mv "${repotab}"{.new,}
}

User-Script.GitHub.CLI.tag-repo() {
: param '~ <Owner/Name> <Tag ...>'
: TODO '~ owner/name +tag1 -tag2 +tag3'
  local owner_name=${1/\/\/.} tag=${*:2}
  local -n tag_upd='us_gh_dirty["$owner_name.tag"]'

  tag_upd=$tag
  declare -p us_gh_dirty >"${US_GH_STATE_DIRTY:?}"
}

User-Script.GitHub.CLI.apply-repo-settings() {
: param ' ~ <Repo-list> <Settings> ...'
  local -n _RepoList=${1:?} _Settings=${2:?}

  for owner_name in "${_RepoList[@]}"; do
    :
  done
}

User-Script.GitHub.CLI.apply-repo-settings() {

  # Set aux projects attributes
  for owner_repo in "${us_gh_project_aux[@]-}"; do
    gh repo edit $owner_repo --enable-issues=false &&
    gh repo edit $owner_repo --enable-wiki=false &&
    gh repo edit $owner_repo --enable-projects=false ||
      :failerr "E$? while running for ${owner_repo@Q}"
  done
}

User-Script.GitHub.CLI.workflow-status() {
: TODO '~ [tag1,tag2,...] [branch]'
  User-Script.GitHub.CLI.workflow-status.grep "$@"
}

User-Script.GitHub.CLI.workflow-status.grep() {
: param '~ [grep-match] ...'
: input "${US_GH_REPOS_OWNER_TSV:?}"
  local repotab=$_

  attr="$(IFS=,; echo "${us_gh_runs_state_attr[*]:?}")"

  grep "[[:space:]]$1[[:space:]]" "$repotab" |
  while IFS=$'\t\n' read -r owner name tag defbr _; do
    echo name: $name $defbr
    gh run list --repo "$owner/$name" --branch "${defbr:-.}" \
      --json "$attr" --limit 1 ||
      return
  done
}

# Id: gh,us         vim:set ft=bash sw=2 sts=2 et:
