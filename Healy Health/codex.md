# Codex Session Protocol

This file defines the required working process for every Codex session on Healy Health.

## Project tracking files

The project uses three living tracking documents:

- `ROADMAP.md` defines the ordered phases, outcomes, and exit criteria on the path to deployment.
- `TODO.md` is the prioritized, actionable backlog derived from the roadmap and code review.
- `handoff.md` is the short-lived checkpoint from the previous session to the next session.

The documents must agree. `ROADMAP.md` owns direction, `TODO.md` owns work status, and `handoff.md` owns the immediate next actions and current context.

## Start of every session

Before changing code:

1. Read this file completely.
2. Read `handoff.md`, `TODO.md`, and `ROADMAP.md` completely.
3. Inspect `git status` and preserve pre-existing user changes.
4. Verify that the handoff still matches the code and repository state; do not assume an old note is correct.
5. Select work from the current roadmap phase, starting with the highest-priority unblocked TODO.
6. State the session goal and the verification planned for it.

If the requested work conflicts with the tracking files, follow the user's latest request and update all affected tracking files before ending the session.

## During every session

- Keep changes scoped to the selected TODO items.
- Add or update tests for behavior changes whenever practical.
- Treat persisted user workout data as high-value data. Use backward-compatible decoding, validate imports, and avoid destructive migrations.
- Do not mark an item complete until its acceptance criteria are met and relevant verification has passed.
- Record newly discovered bugs or follow-up work in `TODO.md` under the correct roadmap phase instead of leaving only an inline comment.
- Update the roadmap when scope, sequencing, or release criteria materially change.
- Do not overwrite unrelated work or tracked user-specific changes.

## End of every session

Before the final response, all of the following are mandatory:

1. Update `TODO.md`:
   - Check completed work.
   - Add discoveries and follow-ups.
   - Keep priorities and phase assignments current.
2. Update `ROADMAP.md`:
   - Refresh the phase status and exit criteria.
   - Record material scope or sequencing decisions.
3. Rewrite `handoff.md` in full for the next session. Do not append a running diary.
4. Reconcile all three documents so the same item is not simultaneously complete and pending.
5. Run the strongest relevant checks available and record the exact commands and outcomes in `handoff.md`.
6. Inspect the final diff and working tree. Clearly distinguish this session's changes from pre-existing changes.

## Required `handoff.md` structure

Every handoff must contain:

- Last updated date
- Current roadmap phase
- What was completed this session
- Exact next actions in priority order, using TODO IDs
- Verification run and its result
- Known blockers or risks
- Important decisions and context
- Working-tree notes, including pre-existing changes

Keep the handoff concise enough to scan at the beginning of a session. Durable requirements belong in `codex.md`; durable backlog belongs in `TODO.md`; phase strategy belongs in `ROADMAP.md`.

## Definition of done

A code task is done only when:

- The requested behavior is implemented.
- Relevant tests or checks pass, or a documented environment blocker explains why they could not run.
- Failure and empty states have been considered.
- Persisted-data compatibility has been considered.
- `TODO.md`, `ROADMAP.md`, and `handoff.md` are updated.

## GitHub authentication

- Do not treat `gh auth status` as a prerequisite for committing or pushing. This workspace may use Git credential-manager authentication that is separate from the GitHub CLI and can remain valid when the CLI points at a different account.
- For a user-requested commit/push, use the configured Git remote and report only an actual `git push` authentication failure. Prefer the connected GitHub integration for GitHub-specific work such as pull-request or Actions inspection.
- The sandboxed shell can expose a stale `gh` identity that is not the user's active GitHub authentication. Do not diagnose, reauthenticate, or rely on that sandbox identity. For GitHub-specific reads and Actions inspection, use the connected GitHub integration. When a new user terminal session is available, use that terminal's GitHub authentication only if CLI access is truly required.
