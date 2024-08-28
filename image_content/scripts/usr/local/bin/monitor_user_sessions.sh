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

HOSTNAME=$(echo $HOSTNAME)

## as we are working with interactive sessions
## TTY is allocated for container in /dev/tty
## 1st Pseudo TTY (PTS) -> /dev/pts/0 is allocated for all processes started using catatonit
## PTS/1, PTS/2 and so on are allocated either as a result of sshd session or screen/tmux sessions

## this means we don't require to check for number of processes

check_running_sessions(){
    ## get pid of main sshd
    sshd_server_pid=$(pgrep sshd | head -n1)
    probe_pid=$$
    
    ## check, if except current $PID and beyond sshd PID there are running processes
    ## example of no sessions
    ## sshd_server_pid=16
    ## probe_pid=4875

    echo "sshd_server_pid $sshd_server_pid , probe_pid $probe_pid"

    echo "sshd_server_pid $sshd_server_pid , probe_pid $probe_pid" >> $HOME/sshd_pid_probe_pid

    ## iterate over /proc file system, find only process IDs
    proc_list=$(ls /proc | egrep "[0-9]")

    proc_count=0
    ## we count number of processes, we have to include possibility of sshd[accepted] process
    ## which is tcp connection to port 2022, issued by sidecar
    for process_id in $proc_list;
    do
      if [ $process_id -gt $sshd_server_pid ] &&  [ $process_id -lt $probe_pid   ] ; then
        echo $process_id;
        proc_count=$((proc_count+1))
      fi
    done;

    ## terminate pod gracefully
    if [[ $proc_count -le 1 ]]; then
       logger -e "Terminating pod for user $USER, no additional sessions are running."
       echo "Terminating pod for user $USER, no additional sessions are running." >> /dev/termination-log
       schedule_pod_termination.sh &
       exit 0
    fi
}

source /usr/local/bin/validate_odp_token.sh

	
#Check the SSO token validity
is_odp_session_token_valid() {
  
  is_odp_session_token_valid_enm
  if [ "$?" -ne 0 ]; then
    logger -e "$USER ODP session token has expired, exiting."
    echo "$USER ODP session token has expired, exiting." >> /dev/termination-log
    schedule_pod_termination.sh &
    exit 0
  fi
}

reload_sshd_configuration(){
	## check, if we need to reload sshd configuration
	if [[ -f $ODP_INTERACTIVE_SESSION_TIMEOUT_FILE ]]; then
	   CHECKSUM=$(sha256sum $ODP_INTERACTIVE_SESSION_TIMEOUT_FILE)
	   
	   CHECKSUM_FILE="/tmp/$ODP_INTERACTIVE_SESSION_TIMEOUT_FILENAME.checksum"
	   
	   ## if file exists, compare 
	   if [[ -f $CHECKSUM_FILE ]]; then
	      PREVIOUS_CHECKSUM=$(head -n 1 $CHECKSUM_FILE)
	      
	      ## reload sshd configuration, if checksums are different
	      if [[ "$PREVIOUS_CHECKSUM" != "$CHECKSUM" ]]; then
	         echo $CHECKSUM > $CHECKSUM_FILE
	         kill -SIGHUP $(pgrep -f "sshd -D")
	      fi
	      
	   ## if file doesn't exists, create it
	   else
	      echo $CHECKSUM > $CHECKSUM_FILE
	   fi
	fi
}

check_sshd_availability(){
     ## check, if main container is still running
     nc -w 2 localhost 2022 &> /dev/null
     if [ "$?" -ne 0 ]; then
        exit 1
     fi
     exit 0
}


is_odp_session_token_valid
check_running_sessions

exit 0