---
description: Prepare, publish, and verify an OpenChamber GitHub Release; usage: /release <version> [dry-run]
agent: build
---

You are releasing OpenChamber from this repository. Follow @docs/RELEASING.md and treat @.github/workflows/release.yml as the authoritative workflow contract.

Arguments: `$ARGUMENTS`

Accept exactly one semantic version in `X.Y.Z` or `X.Y.Z-prerelease.N` form, followed by an optional `dry-run` token. Stop and request a valid invocation when the arguments are invalid.

Workflow:

1. Set `VERSION` to the requested version. Inspect the worktree and recent release/tag state before making changes. Preserve unrelated worktree changes.
2. Run `bun run version:bump -- "$VERSION"`.
3. Add the matching `## [$VERSION] - YYYY-MM-DD` section below `[Unreleased]` in @CHANGELOG.md. Draft user-facing release notes from the changes since the latest release tag and use the existing changelog style.
4. Run `bun run release:prepare`. Resolve failures that belong to this release preparation. Stop and report blockers outside this scope.
5. Show the version and changelog diff. Obtain explicit confirmation before staging, committing, tagging, pushing, dispatching a workflow, or publishing a release.
6. After confirmation, stage only the five version manifests and @CHANGELOG.md, create `release: v$VERSION`, and create tag `v$VERSION`.
7. Push `main` and only tag `v$VERSION`. A tag push triggers the full desktop and Android Release workflow.
8. When `dry-run` was requested, dispatch the workflow manually instead of creating or pushing a tag:

   ```bash
   gh workflow run release.yml --repo yee94/openchamber --ref main -f version="$VERSION" -f dry_run=true
   ```

9. Monitor the Release workflow. Verify the GitHub Release is published (`isDraft: false`), and inspect its assets. Confirm Android APK/AAB assets and Linux x64/arm64 AppImages with their matching `latest-linux*.yml` manifests.

Constraints:

- The current workflow accepts `version` and optional `dry_run`; it has no `release_scope` input.
- Never expose, print, or modify repository secrets or signing credentials.
- Stop before every irreversible step until the user has explicitly approved it.
- Report the release URL, workflow run URL, version, assets verified, and validation commands that ran.
