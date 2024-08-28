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
###########################################################################
#  The SSH Client idle timeout in seconds.
#  The default is no timeout.
###########################################################################
TMOUT=0

if [[ -f $ODP_INTERACTIVE_SESSION_TIMEOUT_FILE ]]; then
   TMOUT=$(head -n 1 $ODP_INTERACTIVE_SESSION_TIMEOUT_FILE)
fi

readonly TMOUT
export TMOUT