# Blocked Project Repo Audit - 2026-06-29

Post-sleep cleanup audit for projects that were blocked because their resolved folders were not git repos.

## Bootstrap update

Superseded by Tim-approved local git bootstrap on 2026-06-29. The canonical folders below are now local git repos and were advanced with GREEN product commits:

| Project | Current repo root | Baseline commit | Product commit | Current autonomous status |
| --- | --- | --- | --- | --- |
| PromptLab | `C:\Users\codex-agent\Documents\Codex\2026-06-10\i-have-30-percent-of-my\work\promptlab` | `de7705e` | `ce53991` | ready for local showability review |
| FitTrack | `C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-fittrack\work\fittrack` | `b1e8161` | `5efaded` | ready for local showability review |
| Personal Site / Portfolio | `C:\Dev\coletylabs-site` | `f538fba` | `110b362` | ready for local showability review |
| RepoTriage | `C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-repotriage` | `d0263ae` | `f443ed6` | ready for local showability review |

The package/output/scaffold copies listed later in this audit remain non-canonical and should not be mutated unless Tim explicitly promotes one.

## TSF cleanup result

- TSF `git status --short --untracked-files=all` was clean before this note.
- The previously reported Coder Upgrade paths are tracked now, mostly from `8978a3c Add TSF Coder Upgrade Pack V1`.
- Classification: useful TSF feature/support files plus generated TSF status outputs.
- No unknown untracked files were deleted, ignored, staged, or committed blindly.

## Project findings

| Project | Resolved path | Git repo | Branch | HEAD | Status | Available checks | Safe for completion pass |
| --- | --- | --- | --- | --- | --- | --- | --- |
| PromptLab | `C:\Users\codex-agent\Documents\Codex\2026-06-10\i-have-30-percent-of-my\work\promptlab` | no | n/a | n/a | `git status --short` cannot run outside a repo | `npm run build`, `npm run lint`; also `dev`, `preview` | no; read-only inspection or TSF-local onboarding only until Tim provides a git root or approves bootstrap |
| PromptLab package copy | `C:\Users\codex-agent\Documents\Codex\2026-06-10\i-have-30-percent-of-my\work\promptlab-package` | no | n/a | n/a | non-git package copy | `npm run build`, `npm run lint`; also `dev`, `preview` | no; package copy should not be mutated as the canonical repo |
| FitTrack | `C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-fittrack\work\fittrack` | no | n/a | n/a | `git status --short` cannot run outside a repo | `npm run build`, `npm run lint`; also `dev`, `preview` | no; needs a git root or Tim-approved bootstrap |
| FitTrack output copy | `C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-fittrack\outputs\fittrack` | no | n/a | n/a | non-git output copy | `npm run build`, `npm run lint`; also `dev`, `preview` | no; output copy should not be mutated as the canonical repo |
| Personal Site / Portfolio | `C:\Dev\coletylabs-site` | no | n/a | n/a | `git status --short` cannot run outside a repo | static HTML/CSS only; no package scripts found | no; needs a git root or Tim-approved bootstrap |
| Personal Site scaffold | `C:\Users\codex-agent\Documents\Codex\2026-06-10\you-are-creating-a-starter-plan\outputs\personal-site` | no | n/a | n/a | non-git scaffold | static HTML/CSS only; no package scripts found | no; scaffold is reference material only until promoted |
| RepoTriage | `C:\Users\codex-agent\Documents\Codex\2026-06-10\build-a-polished-mvp-called-repotriage` | no | n/a | n/a | `git status --short` cannot run outside a repo | `npm run build`; also `dev`, `preview`; no lint script found | no; needs a git root or Tim-approved bootstrap |

## Next safe action

Use the bootstrapped canonical repo roots in the Bootstrap update table for future local-only completion or showability reviews. Do not use the non-canonical package/output/scaffold copies unless Tim explicitly promotes one.

Suggested prompt:

~~~text
Use TSF's bootstrapped project repo audit.
Review PromptLab, FitTrack, Personal Site / Portfolio, and RepoTriage from the canonical repo roots listed in the Bootstrap update.
Do not push, deploy, install packages, run migrations, touch secrets, set remotes, mutate non-canonical copies, or inspect unrelated projects.
~~~
