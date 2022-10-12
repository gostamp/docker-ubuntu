# shellcheck shell=bash

# Color prompt: "user@host(env):dir"
export PS1="\[\033[01;32m\]\u@\h(\$APP_ENV)\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
export TERM=xterm-256color

# A proper `ls` :)
alias ls="ls -alhp --color=auto"

# Set LS_COLORS for `tree`
eval "$(dircolors -b)"

if [ "${APP_TARGET}" == "full" ]; then
    export EDITOR=nano

    # Setup shell completion
    if [ -f /etc/bash_completion ]; then
        # shellcheck source=/dev/null
        source /etc/bash_completion
    fi
    complete -C aws_completer aws
fi
