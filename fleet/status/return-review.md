# Product Acceptance QA Scoreboard

Generated after the local acceptance QA pass across the six completed/bootstrapped projects.

## Top recommendation

Open RepoTriage first if you want a coding force multiplier. It now has a stronger local pasted-input scanner, clearer finding categories, a remediation board, and copy/export markdown reports for future project handoffs.

## Showable now

| Rank | Project | Acceptance result | Latest relevant commit | Checks |
| --- | --- | --- | --- | --- |
| 1 | RepoTriage | Showable local developer tool and now the best next force multiplier. It detects TODO/FIXME, missing tests, risky config, dependency/package signals, suspicious files, docs gaps, and likely entry points from pasted local input. It also shows highest-impact work, safe quick wins, human-decision items, likely checks, and has copy/export report controls. | `c37a2a9` | `npm.cmd run build`; `git diff --check` passed |
| 2 | PrivateLens | Showable privacy analyzer. Anomaly sensitivity updates the report, local markdown download is present, no browser console errors. | `35ea483` | `npm.cmd run build`; `npm.cmd run lint`; `git diff --check` passed |
| 3 | PromptLab | Showable eval console. CSV import adds a new case with citation coverage assertion, export/run controls are visible, no browser console errors. | `ce53991` | `npm.cmd run build`; `npm.cmd run lint`; `git diff --check` passed |
| 4 | FitTrack | Showable job-search tool after acceptance fix. Pasted resume profile now updates name, target roles, skills, keywords, and fit scoring context. | `f4fd395` | `npm.cmd run build`; `npm.cmd run lint`; `git diff --check` passed |
| 5 | Personal Site / Portfolio | Showable static Colety Labs site. Builder/current-work section and public-safe boundary render; static links passed sanity check. | `110b362` | static HTML sanity; static link sanity; `git diff --check` passed |

## Needs one more polish pass

| Project | Why |
| --- | --- |
| Family Tree App | The completed empty-search polish works and the search page has no browser console errors. For full demo readiness, do one more app-level pass with intended auth/data fixtures and route preview, because local static serving cannot exercise Vercel clean-route rewrites or real family-tree data flow. |

## Parked

None. No project needs to be parked from this acceptance pass.

## Fixes made during QA

- FitTrack: `f4fd395 Fix resume paste profile parsing`
  - Normal pasted resume text now updates the profile name and target roles instead of only skills/keywords.

## What can be ignored

- The old non-git blocker is resolved for PromptLab, FitTrack, Personal Site / Portfolio, and RepoTriage.
- Non-canonical package/output/scaffold copies should still be ignored unless Tim explicitly promotes one.
- No push, deploy, install, migration, secrets, remote access, all-fleet command, background daemon, or unrelated project mutation happened.

## Suggested next Codex prompt

~~~text
Use RepoTriage on one real local project.
I will paste a local file tree/snippets or analysis JSON. Help me identify highest-impact fixes, safe quick wins, human-decision items, likely checks, and likely entry points.
Keep it local-only. Do not push, deploy, install packages, run migrations, touch secrets, set remotes, or inspect unrelated projects.
~~~
