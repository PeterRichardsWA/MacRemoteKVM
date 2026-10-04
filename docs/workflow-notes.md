# Workflow Notes

## GitHub

Peter uses a Git GUI for GitHub account authentication, repository creation, and
initial remote setup.

Do not assume GitHub CLI or SSH auth should be used for GitHub repository setup.
After the remote exists, local git operations should include pushing completed
commits to `origin` unless Peter explicitly asks not to push.

## Test Commits

After each completed experiment/test, commit the resulting source, docs, logs,
and result artifacts to the local git repository automatically, then push the
commit to `origin`.

Do not wait for separate confirmation before making these local commits and
pushes.
