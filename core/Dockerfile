FROM ubuntu:16.04
LABEL maintainer="Joey Fang <josudoey@gmail.com>"

ENV OMNICORE_VER          0.4.0
ENV OMNICORE_ARCH         x86_64
ENV OMNICOR_CHECKSUM      03f0da007c70d68fee28641c1ea56566f5d7debbc2858d99977bda409643959a

ENV DATA_DIR             /root/.bitcoin
ENV RPCALLOWIP          "::/0"
ENV RPCUSER              omnicore
ENV RPCPASSWORD          omnicore

RUN apt-get update && apt-get install -qq \
  curl
RUN curl -L "https://bintray.com/artifact/download/omni/OmniBinaries/omnicore-${OMNICORE_VER}-${OMNICORE_ARCH}-linux-gnu.tar.gz" -o omnicore-${OMNICORE_VER}-${OMNICORE_ARCH}-linux-gnu.tar.gz
RUN echo  ${OMNICOR_CHECKSUM} omnicore-${OMNICORE_VER}-${OMNICORE_ARCH}-linux-gnu.tar.gz|sha256sum --check
RUN tar -xvf omnicore-${OMNICORE_VER}-${OMNICORE_ARCH}-linux-gnu.tar.gz --transform="s/^omnicore-0.4.0//" omnicore-0.4.0 -C /

EXPOSE 8332-8333/tcp 18332-18333/tcp
VOLUME ["${DATA_DIR}"]

ADD entrypoint.sh /entrypoint.sh

RUN chmod u+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["omnicored"]
