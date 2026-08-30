# PR Review

This context describes browsing proposed GitLab changes from Neovim and the
explicit action that checks out a merge request's source branch. Browsing does
not mutate the repository, and the plugin never mutates GitLab review state.

## Language

**Merge request**:
A GitLab proposal to merge changes from a source branch into a target branch.
_Avoid_: Pull request, PR

**Raw diff**:
The complete textual diff returned by GitLab for a merge request.
_Avoid_: Patch, changed file

**GitLab instance**:
The GitLab installation that hosts a project, whether GitLab.com, GitLab
Dedicated, or GitLab Self-Managed.
_Avoid_: Enterprise server
