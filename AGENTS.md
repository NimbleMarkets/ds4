# Fork maintenance

`nm-shared` is maintained as a perpetual rebase on upstream `origin/main`
(`antirez/ds4`). The fork remote is `nm` (`NimbleMarkets/ds4`).

For upstream syncs, fetch upstream and rebase the fork commits onto
`origin/main`. Do not merge upstream into `nm-shared`. Preserve the fork's
shared-library, embedded Metal source, logging-hook, and ROCm changes, and
carry forward integration fixes when resolving conflicts. Keep a backup
branch before rewriting history and validate the resulting build.

If publishing a rebased branch is requested, use `--force-with-lease` rather
than an unconditional force push.
