#!/bin/bash

export EDITOR=nano

# Run scripts
if [ -d /root/run.d ]; then
  for i in /root/run.d/*.sh; do
    if [ -f $i ]; then
      sudo -u root -E "bash" "$i" start
    fi
  done
  unset i
fi

trap 'kill -TERM $PID' SIGHUP SIGINT SIGQUIT SIGTERM

# Run main script
echo "Started"
tail -f /dev/null &
PID=$!
wait $PID

echo "Shutdown container"