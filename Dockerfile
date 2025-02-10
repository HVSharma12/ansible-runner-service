FROM opensuse/tumbleweed:latest

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install dependencies
RUN zypper --non-interactive refresh && \
    zypper --non-interactive install --no-recommends \
    bash ansible wget unzip python311 python311-devel python311-pip python311-setuptools \
    python311-pexpect python311-python-daemon bubblewrap gcc \
    bzip2 openssh openssh-clients python311-psutil \
    glibc-locale glibc-locale-base glibc-i18ndata \
    python311-cryptography python311-Flask-RESTful python311-Flask uwsgi \
    python311-docutils python311-netaddr ansible-runner \
    nginx supervisor python311-PyYAML python311-pyOpenSSL && \
    zypper clean -a && \
    localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 || true

# Prepare folders for shared access and SSH
RUN mkdir -p /etc/ansible-runner-service && \
    mkdir -p /root/.ssh && \
    mkdir -p /usr/share/ansible-runner-service/{artifacts,env,project,inventory,client_cert}

# Set working directory
WORKDIR /root

# Copy application files
COPY ./*.py ansible-runner-service/
COPY ./*.yaml ansible-runner-service/
COPY ./runner_service ansible-runner-service/runner_service
COPY ./samples ansible-runner-service/samples

# Copy configuration files
COPY misc/nginx/nginx.conf /etc/nginx/
COPY misc/nginx/ars_site_nginx.conf /etc/nginx/conf.d/
COPY misc/nginx/uwsgi.ini /root/ansible-runner-service/
COPY misc/nginx/supervisord.conf /root/ansible-runner-service/

# Start services
CMD ["/usr/bin/supervisord", "-c", "/root/ansible-runner-service/supervisord.conf"]
