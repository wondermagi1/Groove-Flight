# Project workflow

The user requires an uploaded Git backup before continuing game changes.

- Before each new round of game code, asset, balance, or visual changes, commit the current authorized workspace state to a `codex/backup-*` branch, push it to `origin`, and verify that the remote commit SHA matches the local snapshot.
- The configured project repository is `https://github.com/wondermagi1/Groove-Flight.git`.
- A local commit alone does not satisfy this requirement. If upload or verification fails, stop game edits until the remote backup is restored. Read-only inspection and backup preparation may continue.
- Preserve backup branches. Continue implementation on a separate `codex/*` development branch. Commit and upload the completed, checked version as well.
- The user has authorized this backup workflow. Do not ask for repeated permission unless the destination or scope changes or a tool requires it.
- Existing user decisions: sequencer1second/eight cells, fixed per-weapon sounds and independent same-type layering; ordinary enemies do not shoot and advance every0.5seconds; enemies enter from around the player. Matrix births use one model per batch and have individual movement afterwards. The user subsequently added circular radial-expansion births (reference8:35), overriding the earlier matrix-only restriction. Nearest units attack in arcs/fans; others encircle through the world, including offscreen routes. Preserve complete individual hulls and avoid overlap. See docs/ENEMY_FORMATIONS_AND_ENCIRCLEMENT.md.
