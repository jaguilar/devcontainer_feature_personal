# Personal Customizations Dev Container Feature

A Dev Container Feature that configures my own personal development 
customizations. For now, it forwards the .gemini and .pi directories to
the devcontainer. Both are forwarded as read-only bind mounts. The gemini
directory has a writable overlay. The .pi directory has a writable overlay
only in for the session history -- the settings are meant to be completely
unwritable.

WARNING: I had antigravity compose this for me. It's only tested insofar as
the tests in the test directory validate the behavior. It's meant to be a
"best-effort" attempt at limiting the agents' ability to change their settings
in the dev container or edit the host. It's almost certainly not bullet proof.
