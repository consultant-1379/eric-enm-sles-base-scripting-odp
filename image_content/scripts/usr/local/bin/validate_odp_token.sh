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

# THIS needs to be provided in chart of odp pod for remote desktop, to override default value
# by default it is sourced from the image
printenv ODP_SESSION_TOKEN_FILENAME

if [[ $? -ne 0 ]]; then
   echo "ODP_SESSION_TOKEN_FILENAME is not defined."
   exit 1
fi

is_odp_session_token_valid_enm() {
  SESSIONUID="sessionUid"

  response=$(curl -v --header "X-OpenAM-username: $USER" -k -X POST https://sso:8443/${SSO_REST_PATH} 2> /dev/null)

  #to handle both conditions
  #user is created with ALL CAPITAL LETTERS, e.g. EMTEST
  #you log into ENM as EMTEST, in response you get emtest as username
  #you log into ENM as emtest, in response you get EMTEST as username
  
  
  echo -n "$response\n"

  enm_sso_realm="/"

  if [[ ("${response,,}" == {\"valid\":true,\"${SESSIONUID,,}\":\"*\",\"uid\":\"${USER,,}\",\"realm\":\"${enm_sso_realm,,}\"}) ||  \
      ("${response,,}" == {\"valid\":true,\"uid\":\"${USER,,}\",\"realm\":\"${enm_sso_realm,,}\"}) ]]; then
    return 0
  fi

  echo "$USER ODP session token has expired, exiting."
  return 1
}


## read ODP Token from file system
export ODP_TOKEN=$(head -n 1 $ERIC_ODP_HOME/$ODP_SESSION_TOKEN_FILENAME)

#The rest endpoint for checking the validity of sso token
export SSO_REST_PATH="singlesignon/pam/validate/${ODP_TOKEN}"