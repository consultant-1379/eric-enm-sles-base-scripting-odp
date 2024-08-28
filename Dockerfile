#
# COPYRIGHT Ericsson 2024
#
#
#
# The copyright to the computer program(s) herein is the property of
#
# Ericsson Inc. The programs may be used and/or copied only with written
#
# permission from Ericsson Inc. or in accordance with the terms and
#
# conditions stipulated in the agreement/contract under which the
#
# program(s) have been supplied.
#

ARG ERIC_ODP_MAIN_CONTAINER_IMAGE_NAME=eric-odp-main-container
ARG ERIC_ODP_MAIN_CONTAINER_IMAGE_REPO=armdocker.rnd.ericsson.se/proj-eric-oss-drop
ARG ERIC_ODP_MAIN_CONTAINER_IMAGE_TAG=1.0.0-4
ARG IMAGE_BUILD_VERSION

FROM ${ERIC_ODP_MAIN_CONTAINER_IMAGE_REPO}/${ERIC_ODP_MAIN_CONTAINER_IMAGE_NAME}:${ERIC_ODP_MAIN_CONTAINER_IMAGE_TAG}

ARG BUILD_DATE=unspecified
ARG IMAGE_BUILD_VERSION=unspecified
ARG GIT_COMMIT=unspecified
ARG ISO_VERSION=unspecified
ARG RSTATE=unspecified

LABEL \
com.ericsson.product-number="CXC 174 3052" \
com.ericsson.product-revision=$RSTATE \
enm_iso_version=$ISO_VERSION \
org.label-schema.name="cENM scripting base image on SLES Pipeline" \
org.label-schema.build-date=$BUILD_DATE \
org.label-schema.vcs-ref=$GIT_COMMIT \
org.label-schema.vendor="Ericsson" \
org.label-schema.version=$IMAGE_BUILD_VERSION \
org.label-schema.schema-version="1.0.0-rc1"

#### TORF-596742
## update configuration of zypper to install man pages
RUN sed -i 's/rpm.install.excludedocs = yes/rpm.install.excludedocs = no/g' /etc/zypp/zypp.conf

ENV container=eric-odp
RUN echo "container=eric-odp" >> /etc/environment

ARG ENM_ISO_REPO_URL=ci-portal.seli.wh.rnd.internal.ericsson.com/static/staticRepos/
ARG ENM_ISO_REPO_VERSION=ENM_24_09_ERICenm_CXP9027091_2_42_1
ARG ENM_ISO_REPO_NAME=enm_iso_repo

RUN zypper addrepo -C -G -f https://${ENM_ISO_REPO_URL}${ENM_ISO_REPO_VERSION}?ssl_verify=no $ENM_ISO_REPO_NAME

COPY image_content/repos/*.repo /etc/zypp/repos.d/

## extract content of pam_openam rpm
RUN zypper download ERICpamopenam_CXP9039073 && \
rpm -ivh /var/cache/zypp/packages/enm_iso_repo/ERICpamopenam_CXP9039073*.rpm --allfiles --nodeps --noscripts

## update packages, reinstall rsyslog, to revert to OS based configuration
RUN zypper ref && \
    zypper update -y
    
# rm -rf /etc/rsyslog.conf && \
#    zypper install -f -y rsyslog util-linux-systemd

## add base packages, that are common across all scripting applications

RUN zypper install -y EXTRserverjre_CXP9035480


ENV JAVA_HOME=/usr/java/latest
ENV PATH=$PATH:$JAVA_HOME/bin:/sbin:/usr/sbin/

RUN zypper install -y psmisc binutils iputils iproute2 file file-magic && \
    zypper install -y python311 python311-base python311-curses perl perl-base \
    glibc-locale glibc-locale-base netcat-openbsd python3-pyOpenSSL python3-libxml2 python3-pytz screen time rsyslog vim && \
    zypper clean --all && \
    mkdir -p /usr/share/info && ln -s /var/tmp /usr/tmp
    
## setup for rsyslog running rootless
COPY --chown=root:root image_content/etc/rsyslog.conf /etc/
COPY --chown=root:5004 image_content/scripts/usr/local/bin/logger /usr/local/bin/
RUN chmod +x /usr/local/bin/logger

## fix for missing /var/log/secure in some of the containers
RUN touch /var/log/secure

## prepare environment variables, for configuration for token validation, session validation and session timeout
## ODP_INTERACTIVE_SESSION_TIMEOUT_FILE will be monitored in main container, if it changes
## it means sidecar updated it and we have to reload sshd configuration


ENV ODP_TOKEN_EXPIRED_INDICATOR_FILE="$ERIC_ODP_HOME/.odp_token_expired" \
    ODP_SESSION_TOKEN_FILENAME=.enm_login \
    ODP_INTERACTIVE_SESSION_TIMEOUT_FILENAME=.interactive_session_timeout \
    ODP_INTERACTIVE_SESSION_TIMEOUT_FILE="$ERIC_ODP_HOME/.interactive_session_timeout" \
    ODP_SESSION_TOKEN_CHECK_INTERVAL=5 \
    INTERACTIVE_SESSION_CONFIGURATION_FILE=/ericsson/eric-odp/enm/scripting/session-configuration.conf \
    SSHD_CONF="$ERIC_ODP_HOME/sshd/sshd_config" \
    LIVENESS_PROBE_DELAY=20 \
    LIVENESS_PROBE_INTERVAL=5 \
    SINGLE_SESSION_INDICATOR=.single_session

RUN echo "ODP_TOKEN_EXPIRED_INDICATOR_FILE=$ERIC_ODP_HOME/.odp_token_expired" >> /etc/environment
RUN echo "ODP_SESSION_TOKEN_FILENAME=.enm_login" >> /etc/environment
RUN echo "ODP_INTERACTIVE_SESSION_TIMEOUT_FILENAME=.interactive_session_timeout" >> /etc/environment
RUN echo "ODP_INTERACTIVE_SESSION_TIMEOUT_FILE=$ERIC_ODP_HOME/.interactive_session_timeout" >> /etc/environment
RUN echo "ODP_SESSION_TOKEN_CHECK_INTERVAL=5" >> /etc/environment && \
echo "INTERACTIVE_SESSION_CONFIGURATION_FILE=/ericsson/eric-odp/enm/scripting/session-configuration.conf" >> /etc/environment && \
echo "SSHD_CONF=$ERIC_ODP_HOME/sshd/sshd_config" >> /etc/environment


RUN echo "LIVENESS_PROBE_DELAY=20" >> /etc/environment && \
    echo "LIVENESS_PROBE_INTERVAL=10" >> /etc/environment && \
    echo "SINGLE_SESSION_INDICATOR=.single_session" >> /etc/environment
    

COPY image_content/scripts/usr/local/bin/* /usr/local/bin/
COPY image_content/scripts/etc/profile.d/*.sh /etc/profile.d/

## chmod 777 for debugging 
RUN chmod +x /usr/local/bin/* && \
    chmod 777 /usr/local/bin/*

## apply compatiblity for scripts, that tried to run with default system python
RUN cp /usr/bin/python3 /usr/bin/python

##enm specific
ENV GLOBAL_CONFIG="/ericsson/tor/data/global.properties"

USER 0

#FROM base AS standalone
#RUN cp /ericsson/ERICpamopenam_CXP9039073/libERICpamopenam_CXP9039073.so /lib64/security
#COPY --chown=root:root image_content/etc/pam.d/* /etc/pam.d/
