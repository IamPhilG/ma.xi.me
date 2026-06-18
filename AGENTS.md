# mA.xI.me for Codex

This repository adapts mA.xI.me for Claude Code, GitHub Copilot, and Codex.

## Repository Expectations

- Treat `CLAUDE.md` as the shared methodological base for this repo.
- Use the loop `SPEC -> PLAN -> LIVRABLE -> VERIFY -> REVIEW -> IMPROVE` for significant work.
- Make assumptions explicit and do not present assumptions as facts.
- Do not make destructive or irreversible changes without explicit user approval.
- Keep changes small, justified, and directly tied to the requested scope.
- Run the most relevant verification available before calling work complete.
- If a logical verification was not executed, write: `non verifie par execution`.

## Codex-Specific Guidance

- Prefer repo instructions in this file for durable Codex behavior.
- Prefer `.agents/skills/maxime-*` for reusable workflows that Codex should discover in this repo.
- Use global guidance from `~/.codex/AGENTS.md` only for personal defaults across repos.
- Use `$HOME/.agents/skills` for global Codex skills.

## Project Map

- `CLAUDE.md`: universal method and reliability rules.
- `agents/`: Claude Code agents.
- `skills/`: Claude Code skills and the source copied to global Codex skills.
- `.copilot/`: GitHub Copilot instructions, agents, prompts, and local memory template.
- `.agents/skills/`: repo-scoped Codex skills.
- `.codex/AGENTS.md`: source template for global Codex guidance.
- `install/`: installers for Claude, Copilot, and Codex.
- `tools/check-codex-skills-sync.*`: checks that Codex skills match the source skills.

## Verification

- For installer changes, run the relevant dry-run or `-WhatIf` mode.
- For skill changes, run `powershell -File tools\check-codex-skills-sync.ps1` or `bash tools/check-codex-skills-sync.sh`.
- For documentation-only changes, verify links, paths, and install commands by inspection.
