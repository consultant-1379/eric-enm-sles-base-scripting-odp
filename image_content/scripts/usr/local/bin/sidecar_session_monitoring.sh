#!/bin/bash

###########################################################################
# COPYRIGHT Ericsson 2024
#
# The copyright to the computer program(s) herein is the property of
# Ericsson Inc. The programs may be used and/or copied only with written
# permission from Ericsson Inc. or in accordance with the terms and
# conditions stipulated in the agreement/contract under which the
# program(s) have been supplied.
###########################################################################

source /usr/local/bin/monitor_session_configuration.sh
mkdir -p /var/lib/eric-odp/rsyslogd
rsyslogd -i /var/lib/eric-odp/rsyslogd.pid &
seconds=0
while true; do
  if [ "${seconds}" -ge $LIVENESS_PROBE_INTERVAL ]; then
  
     ## check, if main container is still running
     nc -w 2 localhost 2022 &> /dev/null
     
     if [ "$?" -ne 0 ]; then
        logger -e "Terminating, as the main container was terminated."
        echo "Terminating, as the main container was terminated."
        exit 0 # required for graceful shutdown of sidecar container
     fi
     #configure_shell_and_sshd_timeout
  fi

  sleep 1
  seconds=$((seconds + 1))
done

