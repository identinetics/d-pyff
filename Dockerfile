FROM intra/centos7_py36_base

RUN yum -y update \
 && yum -y install logrotate sudo sysvinit-tools wget xmlstarlet \
 && yum -y install usbutils gcc gcc-c++ git redhat-lsb-core \
                   opensc pcsc-lite engine_pkcs11 gnutls-utils softhsm unzip \
 && yum -y install python-pip python-devel libxslt-devel swig \
 && yum clean all

# use easy_install, solves install bug
# InsecurePlatformWarning can be ignored - this system does not use TLS
RUN pip install six \
 && easy_install --upgrade six \
 && pip install importlib
# using iso8601 0.1.9 because of str/int compare bug in pyff;
# using more-itertools<6.0.0 because of SyntaxError mit more.py line 329
RUN pip install babel future iso8601==0.1.9 'more-itertools<6.0.0' \
 && pip install lxml \
 && pip install pykcs11 parse pytest

#RUN pip install pykcs11==1.3.0 # using pykcs11 1.3.0 because of missing wrapper in v 1.3.1 - tested with 1.4.2: OK
# use leifj's fork of pykcs11
#ENV repodir='/opt/source/PyKCS11'
#ENV repourl='https://github.com/leifj/PyKCS11'
#RUN mkdir -p $repodir && cd $repodir \
# && git clone $repourl . \
# && python setup.py install

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

# changed defaults for c14n, digest & signing alg - used rhoerbe fork
ENV repodir='/opt/source/pyXMLSecurity'
ENV repourl='https://github.com/rhoerbe/pyXMLSecurity'
# the branch has patches for sig/digest als and unlabeld privated keys in HSM
ENV repobranch='rh_fork'
RUN mkdir -p $repodir && cd $repodir \
 && git clone $repourl . \
 && git checkout $repobranch \
 && python setup.py install

# mdsplit function has not been pushed upstream yet - used rhoerbe fork
# auto-installing  Cherry-Py dependency failed with 7.1.0 (UnicodeDecodeError)
RUN pip install 'cherrypy<18.0.0'
COPY install/opt/pyFF /opt/source/pyff/
RUN cd /opt/source/pyff/ && python setup.py install
#ENV repodir='/opt/source/pyff'
#ENV repourl='https://github.com/identinetics/pyFF'
#RUN mkdir -p $repodir && cd $repodir \
# && git clone $repourl . \
# && git checkout i18n \
# && python setup.py compile_catalog \
# && python setup.py install
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


# For development/debugging - map port in config and start sshd with /start_sshd.sh
#RUN yum -y install openssh-server \
# && yum clean all \
# && echo changeit | passwd -f --stdin $USERNAME \
# && echo changeit | passwd -f --stdin root \
# && echo 'GSSAPIAuthentication no' >> /etc/ssh/sshd_config \
# && echo 'useDNS no' >> /etc/ssh/sshd_config \
# && rm -f /etc/ssh/ssh_host_*_key  # generate on first container start, not in image
#COPY dscripts/templates/install/scripts/start_sshd.sh /
#RUN chmod +x /start_sshd.sh
#VOLUME /etc/sshd
#EXPOSE 2022

#create /ramdisk creation for certs - not required for unit tests
RUN mkdir -p /ramdisk \
 && mkdir /tests/.pytest_cache \
 && chown pyff /ramdisk /tests/.pytest_cache

# create manitest for automatic build number generation
USER $USERNAME
COPY install/opt/bin/manifest2.sh /opt/bin/manifest2.sh

EXPOSE 8080
CMD ["/scripts/start_pyffd.sh"]
