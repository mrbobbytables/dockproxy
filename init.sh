#!/bin/bash

if [[ -z "$REG_ADDR" ]] && [[ "$DOCKREG_PORT" ]]; then
   export REG_ADDR=$(echo $DOCKREG_PORT | sed -n -r 's_.*\://(.*)\:.*_\1_p')
   export REG_PRT=$(echo $DOCKREG_PORT | sed -n -r 's_.*\:([0-9].*)$_\1_p')
else
    echo "No Registry Address specified, terminating."
    exit
fi

# Sets REG_PRT to 5000 only if it was not set.
export REG_PRT=${REG_PRT:-5000}

echo "Starting supervsiord"
echo "REG_ADDR: $REG_ADDR"
echo "REG_PRT: $REG_PRT"
supervisord -n -c /etc/supervisord/conf.d/dockproxy.conf
