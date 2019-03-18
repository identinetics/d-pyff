#!/bin/bash

while getopts ':v' opt; do
  case $opt in
    v) verbose_opt='-v';;
    *) echo "usage: $0 OPTIONS
       Configure apache + shibd and generate SP metadata

       OPTIONS:
       -v  verbose
       "; exit 0;;
  esac
done
shift $((OPTIND-1))


mkdir -p /var/log/logrotate
mkdir -p /var/log/pyff_history

logrotate $verbose_opt --state /var/log/logrotate/logrotate.status /opt/etc/logrotate/logrotate.conf
