# ====================================================================== #
# Android SDK Docker Image
# ====================================================================== #

# Base image
# ---------------------------------------------------------------------- #
FROM ubuntu:18.04

# Author
# ---------------------------------------------------------------------- #
LABEL maintainer "yueming.chen@sas.com merged from thyrlian@gmail.com"

# support multiarch: i386 architecture
# install Java
# install essential tools
# install Qt
RUN dpkg --add-architecture i386 && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends libncurses5:i386 libc6:i386 libstdc++6:i386 lib32gcc1 lib32ncurses5 lib32z1 zlib1g:i386 && \
    apt-get install -y --no-install-recommends openjdk-8-jdk && \
    #apt-get install -y --no-install-recommends git wget unzip gnupg iproute2 curl gnome-terminal at-spi2-core && \
    apt-get install -y --no-install-recommends git wget unzip gnupg iproute2 curl xvfb lsof vim && \
    apt-get install -y --no-install-recommends qt5-default


# download and install Android SDK
# https://developer.android.com/studio#command-tools
#ARG ANDROID_SDK_VERSION=6200805
ENV ANDROID_HOME /opt/android-sdk
#RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
#    wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip && \
#    unzip *tools*linux*.zip -d ${ANDROID_HOME}/cmdline-tools && \
#    rm *tools*linux*.zip

# set the environment variables
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH ${PATH}:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator
ENV _JAVA_OPTIONS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap
# WORKAROUND: for issue https://issuetracker.google.com/issues/37137213
ENV LD_LIBRARY_PATH ${ANDROID_HOME}/emulator/lib64:${ANDROID_HOME}/emulator/lib64/qt/lib
# patch emulator issue: Running as root without --no-sandbox is not supported. See https://crbug.com/638180.
# https://doc.qt.io/qt-5/qtwebengine-platform-notes.html#sandboxing-support
ENV QTWEBENGINE_DISABLE_SANDBOX 1

# accept the license agreements of the SDK components
ADD configs/license_accepter.sh /opt/
RUN chmod +x /opt/license_accepter.sh && /opt/license_accepter.sh $ANDROID_HOME

# setup adb server
EXPOSE 5037

# install and configure SSH server
EXPOSE 22
ADD configs/sshd-banner /etc/ssh/
ADD authorized/authorized_keys /tmp/
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends openssh-server supervisor locales && \
    mkdir -p /var/run/sshd /var/log/supervisord && \
    locale-gen en en_US en_US.UTF-8 && \
    apt-get remove -y locales && apt-get autoremove -y && \
    FILE_SSHD_CONFIG="/etc/ssh/sshd_config" && \
    echo "\nBanner /etc/ssh/sshd-banner" >> $FILE_SSHD_CONFIG && \
    echo "\nPermitUserEnvironment=yes" >> $FILE_SSHD_CONFIG && \
    ssh-keygen -q -N "" -f /root/.ssh/id_rsa && \
    FILE_SSH_ENV="/root/.ssh/environment" && \
    touch $FILE_SSH_ENV && chmod 600 $FILE_SSH_ENV && \
    printenv | grep "JAVA_HOME\|GRADLE_HOME\|KOTLIN_HOME\|ANDROID_HOME\|LD_LIBRARY_PATH\|PATH" >> $FILE_SSH_ENV && \
    FILE_AUTH_KEYS="/root/.ssh/authorized_keys" && \
    touch $FILE_AUTH_KEYS && chmod 600 $FILE_AUTH_KEYS && \
    for file in /tmp/*.pub; \
    do if [ -f "$file" ]; then echo "\n" >> $FILE_AUTH_KEYS && cat $file >> $FILE_AUTH_KEYS && echo "\n" >> $FILE_AUTH_KEYS; fi; \
    done && \
    cp /tmp/authorized_keys /root/.ssh/ && \
    chown root:root /root/.ssh/authorized_keys && \
    (rm /tmp/*.pub 2> /dev/null || true)

ADD configs/supervisord.conf /etc/supervisor/conf.d/


# install and configure VNC server
ENV USER root
ENV DISPLAY :1
EXPOSE 5901
ADD configs/vncpass.sh /tmp/
ADD configs/watchdog.sh /usr/local/bin/
#ADD supervisord_vncserver.conf /etc/supervisor/conf.d/
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils xfce4 xfce4-goodies xfonts-base dbus-x11 tightvncserver expect && \
    chmod +x /tmp/vncpass.sh; sync && \
    /tmp/vncpass.sh && \
    rm /tmp/vncpass.sh && \
    apt-get remove -y expect && apt-get autoremove -y && \
    FILE_SSH_ENV="/root/.ssh/environment" && \
    echo "DISPLAY=:1" >> $FILE_SSH_ENV


#====================================
# Install latest nodejs, npm, appium
# Using this workaround to install Appium -> https://github.com/appium/appium/issues/10020 -> Please remove this workaround asap
#====================================
ARG APPIUM_VERSION=1.15.1
ENV APPIUM_VERSION=$APPIUM_VERSION

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash && \
    apt-get -qqy install nodejs && \
    npm install -g appium@${APPIUM_VERSION} --unsafe-perm=true --allow-root --chromedriver-skip-install && \
    exit 0 && \
    npm cache clean && \
    apt-get remove --purge -y npm && \
    apt-get autoremove --purge -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    apt-get clean
    

RUN mkdir /scripts
ADD scripts/ /scripts/
RUN chmod +x /scripts/*.sh
#ADD authorized_keys/authorized_keys /root/.ssh/
#RUN chown root:root /root/.ssh/authorized_keys

#==================================
# Fix Issue with timezone mismatch
#==================================
#ENV TZ="US/Pacific"
#RUN echo "${TZ}" > /etc/timezone

#===============
# Expose Ports
#---------------
# 4723
#   Appium port
#===============
EXPOSE 4723

ENTRYPOINT ["/usr/bin/supervisord"] 
#ENTRYPOINT ["/bin/sh","-c","/scripts/launchAppium.sh"]
#ENTRYPOINT [ "/bin/sh","-c","/scripts/startup.sh" ]

#CMD ["/bin/sh", "/scripts/launchAppium.sh"] && ["/bin/sh","/scripts/launchAVD.sh"] && ["/bin/sh","adb","wait-for-device"] && ["/bin/sh","tail","-f","/dev/null"]