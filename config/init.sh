#!/bin/bash

if [[ "$DOCKREG_V1_PORT" ]]; then
   export REG_V1_ADDR=$(echo $DOCKREG_V1_PORT | sed -n -r 's_.*\://(.*)\:.*_\1_p')
   export REG_V1_PRT=$(echo $DOCKREG_V1_PORT | sed -n -r 's_.*\:([0-9].*)$_\1_p')
fi

if [[ "$DOCKREG_V2_PORT" ]]; then
   export REG_V2_ADDR=$(echo $DOCKREG_V2_PORT | sed -n -r 's_.*\://(.*)\:.*_\1_p')
   export REG_V2_PRT=$(echo $DOCKREG_V2_PORT | sed -n -r 's_.*\:([0-9].*)$_\1_p')
fi

if [[ -z "$REG_V1_ADDR" ]] && [[ -z "$REG_V2_ADDR" ]]; then
    echo "[$(date)][Init] No registry addresses were specified, terminating init."
    exit
fi

# Set the LDAP Bind password in runtime.
BIND_PASSWORD=${BIND_PASSWORD:-defaultpassword}
sed -i "s/BIND_PASSWORD/$BIND_PASSWORD/" /etc/nslcd.conf

# Sets REG_V1_PRT to 5000 only if it was not set.
export REG_V1_PRT=${REG_V1_PRT:-5000}
export REG_V1_SEARCH=${REG_V1_SEARCH:-disabled}
export REG_V2_PRT=${REG_V2_PRT:-5000}
export REDPILL=${REDPILL:-enabled}

# Redpill is enabled by default
if [ "$REDPILL" == "disabled" ] && [ -e /etc/supervisor/conf.d/999-redpill.conf ]; then
    mv /etc/supervisor/conf.d/999-redpill.conf /etc/supervisor/conf.d/999-redpill.disabled
fi


echo "[$(date)][Registry_v1][Address] $REG_V1_ADDR"
echo "[$(date)][Registry_v1][Port] $REG_V1_PRT"
echo "[$(date)][Registry_v1][Search] $REG_V1_SEARCH"
echo "[$(date)][Registry_v2][Address] $REG_V2_ADDR"
echo "[$(date)][Registry_v2][Port] $REG_V2_PRT"
echo "[$(date)][Redpill] $REDPILL"
echo "[$(date)][Supervisor] Starting Supervisor."
supervisord -n -c /etc/supervisor/supervisord.conf
