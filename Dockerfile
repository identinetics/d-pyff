FROM intra/centos7_py36_base

RUN yum -y update \
 && yum -y install git logrotate sudo redhat-lsb-core sysvinit-tools unzip wget xmlstarlet \
 && yum -y install gcc gcc-c++ python-pip python-devel python-jinja2 libxslt-devel swig \
 && yum -y install pcsc-lite engine_pkcs11 gnutls-utils softhsm usbutils \
 && yum clean all

# Bypass Centos 7 stock OpenSC 0.16 with bugs and key support limited to RSA<=2048
WORKDIR /root
RUN yum -y install autoconf automake gcc libtool pcsc-lite-devel \
                   readline-devel openssl-devel libxslt docbook-style-xsl pcsc-lite-devel \
 && wget https://github.com/OpenSC/OpenSC/releases/download/0.19.0/opensc-0.19.0.tar.gz \
 && tar xfvz opensc-*.tar.gz \
 && cd opensc-* \
 && ./bootstrap \
 && ./configure --prefix=/usr/local --sysconfdir=/etc/opensc \
 && make \
 && make install \
 && mkdir -p /usr/lib64//pkcs11/ \
 && ln -s /usr/lib/opensc-pkcs11.so /usr/lib64/opensc-pkcs11.so \
 && ln -s /usr/lib/opensc-pkcs11.so /usr/lib64/pkcs11/opensc-pkcs11.so \
 && ln -s /usr/local/bin/pkcs11-tool /usr/bin/pkcs11-tool \
 && ln -s /usr/local/bin/pkcs15-tool /usr/bin/pkcs15-tool


# python3 currently used only for manifest generation; pyff is on 2.7
RUN pip3 install pytest

COPY install/opt/pyFF /opt/source/pyff/
RUN pip install setuptools --upgrade \
 && pip install pykcs11

# 2017-05: changed defaults for c14n, digest & signing alg - used rhoerbe fork
ENV repodir='/opt/source/pyXMLSecurity'
ENV repourl='https://github.com/rhoerbe/pyXMLSecurity'
# the branch has patches for sig/digest als and unlabeld privated keys in HSM
ENV repobranch='rh_fork'
RUN mkdir -p $repodir && cd $repodir \
 && git clone $repourl . \
 && git checkout $repobranch \
 && python setup.py install

RUN pip install /opt/source/pyff

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/pyff_batch.log \
 && ln -sf /dev/stderr /var/log/pyff_batch.error

# install Shibboleth XMLSECTOOL used in pyffsplit.sh (requires JRE, but installing JDK because of /etc/alternatives support)
# --- XMLSECTOOL ---
ENV version='2.0.0'
RUN mkdir -p /opt && cd /opt \
 && wget -q "https://shibboleth.net/downloads/tools/xmlsectool/${version}/xmlsectool-${version}-bin.zip" \
 && unzip "xmlsectool-${version}-bin.zip" \
 && ln -s "xmlsectool-${version}" 'xmlsectool-2' \
 && rm "xmlsectool-${version}-bin.zip" \
 && yum -y install java-1.8.0-openjdk-devel.x86_64 \
 && yum clean all
ENV JAVA_HOME=/etc/alternatives/jre_1.8.0_openjdk
ENV XMLSECTOOL=/opt/xmlsectool-2/xmlsectool.sh

COPY install/testdata /opt/testdata
COPY install/testdata/etc/pki/tls/openssl.cnf /opt/testdata/etc/pki/tls/
COPY install/scripts/ /scripts/
COPY install/tests/ /tests/

# Application will run as a non-root user
# DAC Permission strategy: group 0 & no group access for private directories
ARG USERNAME=pyff
ARG UID=343003
ENV GID=0
RUN adduser -g $GID -u $UID $USERNAME \
 && chmod -R +x /scripts/* /tests/* \
 && chmod -R 700 $(find /opt -type d) \
 && chown -R $UID:$GID /opt \
 && mkdir -p /etc/sudoers.d \
 && echo "$USERNAME ALL=(root) NOPASSWD: /usr/sbin/pcscd" > /etc/sudoers.d/$USERNAME

ENV VOLDIRS_UNSHARED="/etc/pki/sign /etc/pyff /home/$USERNAME/.ssh /var/log /var/md_feed"
ENV VOLDIRS_SHARED="/var/md_source"
RUN mkdir -p $VOLDIRS_UNSHARED $VOLDIRS_SHARED \
 && mkdir -p /etc/pki/sign/certs /etc/pki/sign/private \
 && chmod -R 700 $(find $VOLDIRS_UNSHARED -type d) \
 && chmod -R 770 $(find $VOLDIRS_SHARED -type d) \
 && chmod -R 755 $(find /var/md_feed -type d) \
 && chown -R $UID:$GID $VOLDIRS_UNSHARED $VOLDIRS_SHARED
VOLUME /etc/pki/sign /etc/pyff /home/$USERNAME/.ssh /var/log /var/md_feed /var/md_source

COPY install/opt/gitconfig /home/$USERNAME/.gitconfig
COPY install/opt/known_hosts /home/$USERNAME/.ssh/
COPY install/opt/xslt/* /etc/pyff/xslt/
COPY install/opt/html_resources/* /opt/md_feed/

# Install PKCS#11 drivers for Safenet eTokenPro
COPY install/safenet/Linux/Installation/Standard/RPM/RPM-GPG-KEY-SafenetAuthenticationClient /opt/sac/
COPY install/safenet/Linux/Installation/Standard/RPM/SafenetAuthenticationClient-9.1.7-0.x86_64.rpm /opt/sac/SafenetAuthenticationClient_x86_64.rpm
RUN yum -y install gtk2 xdg-utils \
 && rpm --import /opt/sac/RPM-GPG-KEY-SafenetAuthenticationClient \
 && rpm -i /opt/sac/SafenetAuthenticationClient_x86_64.rpm --nodeps \
 && yum clean all
ENV PKCS11_CARD_DRIVER='/usr/lib64/libetvTokenEngine.so'

#create /ramdisk creation for certs - not required for unit tests
RUN mkdir -p /ramdisk /.pytest_cache \
 && chown pyff /ramdisk /.pytest_cache

# create manitest for automatic build number generation
USER $USERNAME
COPY install/opt/bin/manifest2.sh /opt/bin/manifest2.sh

EXPOSE 8080
CMD ["/scripts/start_pyffd.sh"]
