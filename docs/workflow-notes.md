# Workflow Notes

## GitHub

Peter uses a Git GUI for GitHub account authentication, repository creation, and
remote publishing.

Do not assume GitHub CLI or SSH auth should be used for GitHub remote setup.
Local git operations are fine when requested, but GitHub publishing should be
left for the Git GUI unless Peter explicitly asks for another path.

## Test Commits

After each completed experiment/test, commit the resulting source, docs, logs,
and result artifacts to the local git repository automatically.

Do not wait for separate confirmation before making these local commits.
