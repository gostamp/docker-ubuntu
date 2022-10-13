#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset -o pipefail -x

# Builds the pre-commit git hooks and stores them in /opt/build
# The entrypoint will restore them into `.git` on every container run.
# This will ensure that pre-commit is auto-setup w/out needing user input.

# Create the hooks.
git config --global --add safe.directory /app
git init -b main
rm -f .git/hooks/*
pre-commit install --install-hooks

# Wrap the hooks in a script that always runs them in the container.
# Otherwise users who commit from the host (likely many of them) will suffer
# from a ton of latency as pre-commit makes a ton of docker-compose calls.
mv .git/hooks/commit-msg .git/hooks/__commit-msg
cat <<'EOF' >.git/hooks/commit-msg
    #!/usr/bin/env bash
    ./bin/run-in-container.sh .git/hooks/__commit-msg "$@"
EOF
chmod +x .git/hooks/commit-msg
mv .git/hooks/pre-commit .git/hooks/__pre-commit
cat <<'EOF' >.git/hooks/pre-commit
    #!/usr/bin/env bash
    ./bin/run-in-container.sh .git/hooks/__pre-commit "$@"
EOF
chmod +x .git/hooks/pre-commit

# Stash the modified hooks in /opt/build
mkdir -p /opt/build/git
cp .git/hooks/* /opt/build/git/
rm -Rf .git/
