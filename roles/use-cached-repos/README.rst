Clone repos from the image cache into the workspace

Clon any repos cached on the remote node (via the image build process)
that this job uses into the workspace.  If a repo doesn't exist, clone
it from its source.

These repos are neither up to date, nor do they contain the changes
that Zuul has prepared.  A separate role should synchronize the local
and remote repos.
