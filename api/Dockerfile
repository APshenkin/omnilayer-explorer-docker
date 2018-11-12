FROM ubuntu:18.04

#Install deps
RUN apt-get update
RUN apt-get install -y git-core \
                      pkg-config \
                      build-essential \
                      pyqt4-dev-tools \
                      swig \
                      libqtcore4 \
                      libqt4-dev \
                      python-qt4 \
                      python-dev \
                      python-twisted \
                      python-psutil \
                      autotools-dev \
                      autoconf \
                      libtool \
                      python-pip \
                      wget \
                      lsb-core \
                      supervisor

# Install nginx
RUN cd /tmp/ && wget http://nginx.org/keys/nginx_signing.key
RUN apt-key add /tmp/nginx_signing.key
RUN sh -c "echo 'deb http://nginx.org/packages/mainline/ubuntu/ '$(lsb_release -cs)' nginx' > /etc/apt/sources.list.d/nginx.list"
RUN apt-get update && apt-get install nginx


# Install bitcoin armory
WORKDIR /home/ubuntu

ARG ARMORY_VERSION=fee1f91a3137ef1056e15cc606a186b0e508f84c

RUN git clone https://github.com/goatpig/BitcoinArmory.git
WORKDIR /home/ubuntu/BitcoinArmory

RUN git checkout ${ARMORY_VERSION}

RUN git submodule init && git submodule update
RUN  ./autogen.sh && ./configure && make && make install

# Install omniapi
WORKDIR /home/ubuntu

ARG OMNILAYER_VERSION=1d7c7945dbc60ed7a29e5b101fc1021787ed03ce

RUN git clone https://github.com/OmniLayer/omniapi.git
WORKDIR /home/ubuntu/omniapi

RUN git checkout ${OMNILAYER_VERSION}

RUN pip install -r requirements.txt
RUN mkdir /home/ubuntu/omniapi/logs/

#Setup nginx main config
RUN cp  /home/ubuntu/omniapi/etc/nginx/sites-available/default /etc/nginx/conf.d/default.conf

#Setup omniapi configs
COPY bitcoin.conf /home/root/.bitcoin/
COPY sql.conf /home/root/.omni/
COPY config.py /home/ubuntu/omniapi/api/config.py

# Patch rate limit to be able to disable them
COPY flask_rate_limit.py /home/ubuntu/omniapi/api/flask_rate_limit.py

# Patch cacher to be able to use only remote redis
COPY cacher.py /home/ubuntu/omniapi/api/cacher.py

# Patch start script to write logs to stdout
COPY startApi.sh /home/ubuntu/omniapi/startApi.sh

# Patch nginx configuration to be able to use CORS
COPY omni-redirects /home/ubuntu/omniapi/etc/nginx/sites-available/omni-redirects

# Add supervisor conf to launch nginx and api
COPY supervisord.conf /etc/supervisor/conf.d/

EXPOSE 8080
CMD ["/usr/bin/supervisord"]
