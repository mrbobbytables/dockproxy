#!/bin/bash

_terminator() {
    echo "[$(date)][Redpill] SIGNAL trapped, terminating background sleep pid $1."
    kill $1
    exit
}

echo "[$(date)][Redpill] Starting redpill."
echo "[$(date)][Redpill] Monitoring: $@"
echo "[$(date)][Redpill] Sleeping 10 seconds before monitoring start."

sleep 10 & sleep_pid=$!
trap "_terminator $sleep_pid" INT KILL TERM
wait

echo "[$(date)][Redpill] Monitoring started."

while true; do
        for service_name in $@; do
        if [ "$(supervisorctl status $service_name | awk '{print $2}')" == "FATAL" ]; then
            echo "[$(date)][Redpill] $service_name has encountered an unrecoverable error. Terminating supervisor"
            pkill "supervisord"
            exit
        fi
    done
 
    sleep 60 & sleep_pid=$!
    trap "_terminator $sleep_pid" SIGINT SIGKILL SIGTERM
    wait
done
