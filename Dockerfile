FROM intra/centos7_py36_base

RUN yum -y update \
 && yum -y install logrotate sudo sysvinit-tools wget xmlstarlet \
 && yum -y install usbutils gcc gcc-c++ git redhat-lsb-core \
                   opensc pcsc-lite engine_pkcs11 gnutls-utils softhsm unzip \
 && yum -y install python-pip python-devel libxslt-devel swig \
 && yum clean all

# use easy_install, solves install bug
# InsecurePlatformWarning can be ignored - this system does not use TLS
RUN pip3 install pytest

COPY install/opt/pyFF /opt/source/pyff/
RUN cd /opt/source/pyff/ && python setup.py install

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/pyff_batch.log \
 && ln -sf /dev/stderr /var/log/pyff_batch.error

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
RUN mkdir -p /ramdisk \
 && mkdir /.pytest_cache \
 && chown pyff /ramdisk /.pytest_cache

# create manitest for automatic build number generation
USER $USERNAME
COPY install/opt/bin/manifest2.sh /opt/bin/manifest2.sh

EXPOSE 8080
CMD ["/scripts/start_pyffd.sh"]
