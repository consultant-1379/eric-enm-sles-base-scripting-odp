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

readonly SCRIPT_NAME="${0}"
readonly LOG_TAG="SESSION_TIMEOUT_CONFIGURATION"

#############################################################
#
# Logger Functions
#
#############################################################
info() {
  logger -t "${LOG_TAG}" -p user.notice "INFO ( ${SCRIPT_NAME} ): $1"
}

error() {
  logger -t "${LOG_TAG}" -p user.err "ERROR ( ${SCRIPT_NAME} ): $1"
}


#######################################
# Action :
#  configure_sshd_config
#   Configures the sshd for client timeouts by using the global configuration in SSH_TIMEOUT_CONFIG file.
# Globals :
#   _SED
#   _SERVICE
#   SSH_TIMEOUT_CONFIG
#   SSHD_CONF
# Arguments:
#   None
# Returns:
#   None
#######################################
configure_shell_and_sshd_timeout() {
    [[ -f "$INTERACTIVE_SESSION_CONFIGURATION_FILE" ]] && source "$INTERACTIVE_SESSION_CONFIGURATION_FILE" || exit 0

    local client_alive_interval="ClientAliveInterval"
    local client_alive_max_count="ClientAliveCountMax"
    local previous_timeout=$(awk '/^ClientAliveInterval /{print $2}' "$SSHD_CONF")

    if [[ "${previous_timeout}" != "$session_timeout" ]]; then
      local SSH_CLIENT_SESSION_TIMEOUT=$session_timeout
      if [[ $SSH_CLIENT_SESSION_TIMEOUT =~ ^[0-9]+$ ]]; then
        sed -i "/${client_alive_interval} /c\\${client_alive_interval} $SSH_CLIENT_SESSION_TIMEOUT" $SSHD_CONF
        sed -i "/${client_alive_max_count} /c\\${client_alive_max_count} 0" $SSHD_CONF
        echo "$SSH_CLIENT_SESSION_TIMEOUT" > $ODP_INTERACTIVE_SESSION_TIMEOUT_FILE
      elif [[ $SSH_CLIENT_SESSION_TIMEOUT == "0" ]]; then
        sed -i "/^${client_alive_interval} /s/^/#/" $SSHD_CONF
        sed -i "/^${client_alive_max_count} /s/^/#/" $SSHD_CONF
        echo "$SSH_CLIENT_SESSION_TIMEOUT" > $ODP_INTERACTIVE_SESSION_TIMEOUT_FILE
      else
        error "Failed to parse the session timeout configuration"
      fi
    fi
}