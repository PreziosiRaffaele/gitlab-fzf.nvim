# PR Review

This context describes browsing proposed GitLab changes from Neovim without
performing repository or review mutations.

## Language

**Merge request**:
A GitLab proposal to merge changes from a source branch into a target branch.
_Avoid_: Pull request, PR

**Changed file**:
A file-level change belonging to a merge request, including its path, change
status, and patch when GitLab makes one available.
_Avoid_: Diff

**Patch**:
The textual unified-diff representation of one changed file.
_Avoid_: Changed file, full diff

**GitLab instance**:
The GitLab installation that hosts a project, whether GitLab.com, GitLab
Dedicated, or GitLab Self-Managed.
_Avoid_: Enterprise server
