FROM ubuntu:14.04

# install deps
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:openjdk-r/ppa
RUN apt-get update
RUN apt-get install -y git-core \
                      libffi-dev \
                      python-dev \
                      python-psycopg2 \
                      postgresql \
                      libpq-dev \
                      libssl-dev \
                      libcurl4-openssl-dev \
                      python-pip \
                      supervisor \
                      curl \
                      openjdk-8-jre

RUN pip install python-crontab


# install flyway to use it for applying migration (omni team use bad practice - just setup sql files on database. We will use flyway for that)
WORKDIR /flyway

ENV FLYWAY_VERSION 5.2.1

RUN curl -L https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/${FLYWAY_VERSION}/flyway-commandline-${FLYWAY_VERSION}.tar.gz -o flyway-commandline-${FLYWAY_VERSION}.tar.gz \
  && tar -xzf flyway-commandline-${FLYWAY_VERSION}.tar.gz --strip-components=1 \
  && rm flyway-commandline-${FLYWAY_VERSION}.tar.gz \
  && ln -s /flyway/flyway /usr/local/bin/flyway

# Install engine
WORKDIR /root

ARG OMNILAYER_VERSION=b6bb84235bf720e802d26ad215d0b243a16b190f

RUN git clone https://github.com/OmniLayer/omniEngine.git
WORKDIR /root/omniEngine

RUN git checkout ${OMNILAYER_VERSION}

RUN pip install -r requirements.txt

#Setup configs
COPY bitcoin.conf /home/root/.bitcoin/
COPY sql.conf /home/root/.omni/
COPY run.sh /root/omniEngine/run.sh
COPY config.py /root/omniEngine/config.py

# Patch installOmniEngineCronJob to forward network variable and pass logs to docker stdout
COPY installOmniEngineCronJob.py /root/omniEngine/install/installOmniEngineCronJob.py

# Patch omniEngine to force stdout print and use other configuration for testnet
COPY omniEngine.py /root/omniEngine/omniEngine.py
COPY sql.py /root/omniEngine/sql.py
COPY db /flyway/sql/

RUN chmod +x /root/omniEngine/run.sh

RUN mkdir /root/omniEngine/logs

# add supervisor conf to launch nginx and api
COPY supervisord.conf /etc/supervisor/conf.d/

CMD ["/usr/bin/supervisord"]
