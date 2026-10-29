# Bash expands the current user, hostname, directory, and privilege marker.
case $- in
  *i*) PS1='\u@\h:\w\$ '; export PS1 ;;
esac
