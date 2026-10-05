# run-us-gh

## NAME

run-us-gh - fetch, tag and list GitHub repositories (via the `gh` CLI)

## DESCRIPTION

This is mostly exec boilerplate script (run+boilerplate.sh) with a rudimentary
options-to-functions case/esac for the *group part* `us-gh`.

Workflow allows to fetch basic and detailed *repolist*, then tag the basic
list entries, and then filter the list by tag.

## COMMANDS

**Main control and management options**

**--fetch**
: Build local TSV for tagging, with columns: `owner name tags defbr plang stars forks isfrk isarch istpl ispriv`

--fetch-details
: Build local TSV with columns `owner name description diskuse created updated pushed`

--commit
: Apply all changes in local TSV at GitHub

TODO: set archived on/of, set description value
TODO: set tags and other rule stuff in package.yaml project files instead

**Using tag on repositories**

--auto-tag
: Apply all suggestions/mutations to the TSV tag field, now and without reservation.

--reset-tags <Repo>
--suggest-tags
: Generate and show all Tag suggestions now (but make no tag changes)

This runs and caches results for all entries, using the configured auto-suggest
handlers. Use it to speed up manual editing loops and reduce resource use, if
there is noticeable delay or significant costs in retrieving the suggestions
per record.

--set-tag <Repo>
: Edit each tag field by hand, while looping over TSV entries

--tag
: Edit each tag field by hand, while looping over TSV entries

The setting autotags and autoaddtags (default 1 and 0) control the auto-adding
of suggested tags (when value is empty, or regardless of current value).

## EXAMPLES

```bash
  run-us-gh.sh --grep-repolist --column -3 '.*script.*' -i
```

List repos with primary language matching 'script' anywhere, case insensitive.


## STATUS

- [TODO] implement proper tag query on list, via some suitable toolkit method (grep/awk/bash-glob/re)
- [TODO] edit description, archive status, sync with gh
- [TODO] make local complete clone list; set to @Dev or @Src for checkout; clean-up rest
  This requires organizing all the SCM-Git volumes.
- [TODO] add all jobs with CI to @CI; build CI dashboard/terminal view
