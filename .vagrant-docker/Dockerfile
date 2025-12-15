# Based on https://jon.sprig.gs/blog/post/2145
# Which in turn draws from https://vtorosyan.github.io/ansible-docker-vagrant/
# and https://github.com/AkihiroSuda/containerized-systemd/
ARG OS_VERSION=10
FROM almalinux/${OS_VERSION}-base:${OS_VERSION}

# Install this file: https://github.com/AkihiroSuda/containerized-systemd/blob/master/docker-entrypoint.sh
# and set it up to be the default execution
STOPSIGNAL SIGRTMIN+3
COPY --chmod=755 docker-entrypoint.sh /
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/bin/bash" ]

# Setup systemd and system libraries
RUN dnf install -y \
        systemd \
        sudo \
        procps \
        iproute \
        hostname \
        diffutils \
        NetworkManager

# Install the SSH Server
RUN dnf install -y \
        openssh-server \
        openssh-clients && \
    mkdir /var/run/sshd && \
    systemctl enable sshd

# Setup the Vagrant user and "insecure" (common) keys
RUN useradd --create-home -s /bin/bash vagrant && \
    echo -n 'vagrant:vagrant' | chpasswd && \
    echo 'vagrant ALL = NOPASSWD: ALL' > /etc/sudoers.d/vagrant && \
    chmod 440 /etc/sudoers.d/vagrant && \
    mkdir -p /home/vagrant/.ssh && \
    chmod 700 /home/vagrant/.ssh && \
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" > /home/vagrant/.ssh/authorized_keys && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN1YdxBpNlzxDqfJyw/QKow1F+wvG9hXGoqiysfJOn5Y vagrant insecure public key" >> /home/vagrant/.ssh/authorized_keys && \
    chmod 600 /home/vagrant/.ssh/authorized_keys && \
    chown -R vagrant:vagrant /home/vagrant/.ssh
