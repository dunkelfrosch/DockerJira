#
# BUILD    : DF/[ATLASSIAN][JIRA]
# OS/CORE  : blacklabelops/alpine:3.7
# SERVICES : ntp, ...
#
# VERSION 1.0.7
#

FROM blacklabelops/alpine:3.7

ARG ISO_LANGUAGE=en
ARG ISO_COUNTRY=US
ARG JIRA_VERSION=7.9.1
ARG JIRA_PRODUCT=jira-software
ARG MYSQL_CONNECTOR_VERSION=5.1.46
ARG DOCKERIZE_VERSION=v0.6.1
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000
ARG BUILD_DATE=undefined

ENV TERM="xterm" \
    TIMEZONE="Europe/Berlin" \
    JIRA_USER=jira \
    JIRA_GROUP=jira \
    JIRA_CROWD_SSO=false \
    JIRA_CONTEXT_PATH=ROOT \
    JIRA_HOME=/var/atlassian/jira \
    JIRA_INSTALL=/opt/jira \
    JIRA_SCRIPTS=/usr/local/share/atlassian \
    MYSQL_CONNECTOR_URL="http://dev.mysql.com/get/Downloads/Connector-J" \
    DOWNLOAD_URL="https://www.atlassian.com/software/jira/downloads/binary"

ENV JAVA_HOME=$JIRA_INSTALL/jre
ENV PATH=$PATH:$JAVA_HOME/bin \
    LANG=${ISO_LANGUAGE}_${ISO_COUNTRY}.UTF-8

COPY scripts/* ${JIRA_SCRIPTS}/

# prepare directories
RUN mkdir -p ${JIRA_HOME}/caches/indexes \
             ${JIRA_INSTALL}/conf/Catalina \
             ${JIRA_INSTALL}/lib

COPY scripts/* ${JIRA_SCRIPTS}/

# install glibc using origin sources
RUN export GLIBC_VERSION=2.26-r0 && \
    apk add --update ca-certificates gzip curl xmlstarlet wget tzdata tini && \
    wget -q --directory-prefix=/tmp https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk && \
    wget -q --directory-prefix=/tmp https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk && \
    wget -q --directory-prefix=/tmp https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-i18n-${GLIBC_VERSION}.apk && \
    apk add --allow-untrusted /tmp/glibc-${GLIBC_VERSION}.apk && \
    apk add --allow-untrusted /tmp/glibc-bin-${GLIBC_VERSION}.apk && \
    apk add --allow-untrusted /tmp/glibc-i18n-${GLIBC_VERSION}.apk && \
    /usr/glibc-compat/bin/localedef -i ${ISO_LANGUAGE}_${ISO_COUNTRY} -f UTF-8 ${ISO_LANGUAGE}_${ISO_COUNTRY}.UTF-8 && \
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" >/etc/timezone

# --
# testblock_01_SOB
# --
# install jira using origin atlassian (bin) installer
RUN export JIRA_BIN=atlassian-${JIRA_PRODUCT}-${JIRA_VERSION}-x64.bin && \
    wget -q -P /tmp/ https://www.atlassian.com/software/jira/downloads/binary/${JIRA_BIN} && \
    mv /tmp/${JIRA_BIN} /tmp/jira.bin && \
    chmod +x /tmp/jira.bin && /tmp/jira.bin -q -varfile ${JIRA_SCRIPTS}/response.varfile

RUN rm -f ${JIRA_INSTALL}/lib/mysql-connector-java*.jar &&  \
    wget -O /tmp/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.tar.gz                                              \
      http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.tar.gz      &&  \
    tar xzf /tmp/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.tar.gz                                              \
      --directory=/tmp                                                                                        &&  \
    cp /tmp/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}-bin.jar     \
      ${JIRA_INSTALL}/lib/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}-bin.jar
# --
# testblock_01_EOB
# --

RUN export CONTAINER_USER=jira                      &&  \
    export CONTAINER_UID=1000                       &&  \
    export CONTAINER_GROUP=jira                     &&  \
    export CONTAINER_GID=1000                       &&  \
    addgroup -g $CONTAINER_GID $CONTAINER_GROUP     &&  \
    adduser -u $CONTAINER_UID                           \
            -G $CONTAINER_GROUP                         \
            -h /home/$CONTAINER_USER                    \
            -s /bin/bash                                \
            -S $CONTAINER_USER                      &&  \
    # Adding letsencrypt-ca to truststore
    export KEYSTORE=$JAVA_HOME/lib/security/cacerts && \
    wget -P /tmp/ https://letsencrypt.org/certs/letsencryptauthorityx1.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/letsencryptauthorityx2.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x1-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x2-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.der && \
    wget -P /tmp/ https://letsencrypt.org/certs/lets-encrypt-x4-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias isrgrootx1 -file /tmp/letsencryptauthorityx1.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias isrgrootx2 -file /tmp/letsencryptauthorityx2.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx1 -file /tmp/lets-encrypt-x1-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx2 -file /tmp/lets-encrypt-x2-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx3 -file /tmp/lets-encrypt-x3-cross-signed.der && \
    keytool -trustcacerts -keystore $KEYSTORE -storepass changeit -noprompt -importcert -alias letsencryptauthorityx4 -file /tmp/lets-encrypt-x4-cross-signed.der && \
    # Install atlassian ssl tool
    wget -O /home/${JIRA_USER}/SSLPoke.class https://confluence.atlassian.com/kb/files/779355358/779355357/1/1441897666313/SSLPoke.class && \
    # Set permissions
    chown -R $JIRA_USER:$JIRA_GROUP ${JIRA_HOME}    &&  \
    chown -R $JIRA_USER:$JIRA_GROUP ${JIRA_INSTALL} &&  \
    chown -R $JIRA_USER:$JIRA_GROUP ${JIRA_SCRIPTS} &&  \
    chown -R $JIRA_USER:$JIRA_GROUP /home/${JIRA_USER} &&  \
    # Install dockerize
    wget -O /tmp/dockerize.tar.gz https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    tar -C /usr/local/bin -xzvf /tmp/dockerize.tar.gz && \
    rm /tmp/dockerize.tar.gz && \
    # Remove obsolete packages
    apk del                                             \
      ca-certificates                                   \
      gzip                                              \
      wget                                          &&  \
    # Clean caches and tmps
    rm -rf /var/cache/apk/*                         &&  \
    rm -rf /tmp/*                                   &&  \
    rm -rf /var/log/*

# Image Metadata
LABEL com.blacklabelops.application.jira.version=$JIRA_PRODUCT-$JIRA_VERSION \
      com.blacklabelops.application.jira.userid=$CONTAINER_UID \
      com.blacklabelops.application.jira.groupid=$CONTAINER_GID \
      com.blacklabelops.image.builddate.jira=${BUILD_DATE}

USER jira
WORKDIR ${JIRA_HOME}
VOLUME ["/var/atlassian/jira"]
EXPOSE 8080
ENTRYPOINT ["/sbin/tini","--","/usr/local/share/atlassian/entrypoint.sh"]
CMD ["jira"]