# Product Acceptance QA Scoreboard

Generated after the local acceptance QA pass across the six completed/bootstrapped projects.

## Top recommendation

Open Family Tree first for the private birthday/demo release check. The final demo-readiness pass fixed the example/private route boundary, made the sample tree clearly view-only, and kept add/search/profile actions scoped to private trees.

## Showable now

| Rank | Project | Acceptance result | Latest relevant commit | Checks |
| --- | --- | --- | --- | --- |
| 1 | Family Tree App | Demo-ready for the private birthday/demo scope. Example links now clear stored private tree context, the sample tree announces view-only preview mode, Add Relative redirects to dashboard unless a private tree is selected, private-tree mode labels scoped add/search/profile behavior, and the add-person writer no longer saves to the example collection. | `b08b89e` | `scripts/codex-static-check.ps1`; `scripts/codex-guardrails.ps1`; `git diff --check` passed |
| 2 | RepoTriage | Showable local developer tool and coding force multiplier. It detects TODO/FIXME, missing tests, risky config, dependency/package signals, suspicious files, docs gaps, and likely entry points from pasted local input. It also shows highest-impact work, safe quick wins, human-decision items, likely checks, and has copy/export report controls. | `c37a2a9` | `npm.cmd run build`; `git diff --check` passed |
| 3 | PrivateLens | Showable privacy analyzer. Anomaly sensitivity updates the report, local markdown download is present, no browser console errors. | `35ea483` | `npm.cmd run build`; `npm.cmd run lint`; `git diff --check` passed |
| 4 | PromptLab | Showable eval console. CSV import adds a new case with citation coverage assertion, export/run controls are visible, no browser console errors. | `ce53991` | `npm.cmd run build`; `npm.cmd run lint`; `git diff --check` passed |
| 5 | FitTrack | Showable job-search tool after acceptance fix. Pasted resume profile now updates name, target roles, skills, keywords, and fit scoring context. | `f4fd395` | `npm.cmd run build`; `npm.cmd run lint`; `git diff --check` passed |
| 6 | Personal Site / Portfolio | Showable static Colety Labs site. Builder/current-work section and public-safe boundary render; static links passed sanity check. | `110b362` | static HTML sanity; static link sanity; `git diff --check` passed |

## Needs one more polish pass

| Project | Why |
| --- | --- |
| None | Family Tree moved to showable/demo-ready after the route and preview-safety polish pass. |

## Parked

None. No project needs to be parked from this acceptance pass.

## Fixes made during QA

- FitTrack: `f4fd395 Fix resume paste profile parsing`
  - Normal pasted resume text now updates the profile name and target roles instead of only skills/keywords.
- Family Tree App: `b08b89e Polish family tree demo preview flow`
  - Clean example preview links, private-tree scoped add/search/profile copy, and a guard against saving new relatives to the sample collection.

## What can be ignored

- The old non-git blocker is resolved for PromptLab, FitTrack, Personal Site / Portfolio, and RepoTriage.
- Non-canonical package/output/scaffold copies should still be ignored unless Tim explicitly promotes one.
- No push, deploy, install, migration, secrets, remote access, all-fleet command, background daemon, or unrelated project mutation happened.

## Suggested next Codex prompt

~~~text
Run a final local review of Family Tree for the private birthday/demo release.
Open the example preview route and one private-tree route if available. Confirm the sample tree is view-only, add/search/profile actions stay scoped to the selected tree, and no deploy or production resource change is needed.
Keep it local-only. Do not push, deploy Firebase, install packages, run migrations, touch secrets, set remotes, or inspect unrelated projects.
~~~
