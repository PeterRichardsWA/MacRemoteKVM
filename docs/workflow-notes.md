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

## Experiment Packaging

Each experiment directory should be self-contained for the files it needs to run.
Do not make a new test depend on input media from a previous experiment
directory.

Name the runnable shell entry point `test.sh`; the experiment directory name
already describes what the test is.

Write new experiment results to a `results/` subdirectory under that experiment
directory. Do not make Peter copy files from the repository-level `results/`
tree after a run.
