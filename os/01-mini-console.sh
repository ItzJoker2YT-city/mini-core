case $- in *i*) [ ! -t 0 ] || stty -ixon -ixoff 2>/dev/null || true;; esac
