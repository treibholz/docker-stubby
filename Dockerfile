# First create a container to build

FROM alpine:3.9

ENV STUBBY_VERSION v0.2.6
ENV STUBBY_TAG_HASH b0d3154af61e1b46a30b56d239dc074273642217 
ENV GETDNS_VERSION v1.5.2
ENV GETDNS_TAG_HASH ffe471543bd947d6d96ddd212ee987ba3787fb36

# get the build-dependencies
RUN apk add --no-cache git autoconf automake build-base libtool openssl-dev unbound-dev libidn-dev yaml-dev

# build libgetdns
WORKDIR /build
RUN git clone --depth=1 --recurse-submodules https://github.com/getdnsapi/getdns.git -b ${GETDNS_VERSION}
WORKDIR /build/getdns
RUN git rev-parse HEAD --verify | grep ${GETDNS_TAG_HASH} && \
    libtoolize -ci && \
    autoreconf -fi && \
    ./configure CFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" && \
    make && make install

# build stubby
WORKDIR /build
RUN git clone --depth=1 https://github.com/getdnsapi/stubby.git -b ${STUBBY_VERSION}
WORKDIR /build/stubby
RUN git rev-parse HEAD --verify | grep ${STUBBY_TAG_HASH} && \
    autoreconf -vfi && \
    ./configure CFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" && \
    make && make install

# Here we start building the real image.
FROM alpine:3.9

RUN apk add --no-cache unbound-libs libidn yaml tini && \
    adduser -S stubby -u 100 && \
    mkdir -p /var/cache/stubby && \
    chown stubby: /var/cache/stubby

COPY --from=0 /usr/local/ /usr/local/
COPY stubby.yml /etc/stubby/stubby.yml

USER stubby
EXPOSE 10053
ENTRYPOINT ["tini", "--", "stubby"]
CMD ["-C", "/etc/stubby/stubby.yml"]
