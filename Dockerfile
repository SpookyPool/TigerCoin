# daemon runs in the background
# run something like tail /var/log/SpookyCoind/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/SpookyCoind:/var/lib/SpookyCoind -v $(pwd)/wallet:/home/SpookyCoin --rm -ti SpookyCoin:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG SpookyCoin_BRANCH=master
ENV SpookyCoin_BRANCH=${SpookyCoin_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/SpookyCoin/SpookyCoin.git /src/SpookyCoin && \
    cd /src/SpookyCoin && \
    git checkout $SpookyCoin_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/SpookyCoind /usr/local/bin/SpookyCoind && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/SpookyCoind && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/SpookyCoin && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the SpookyCoind service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/SpookyCoind SpookyCoind && \
    useradd -s /bin/bash -m -d /home/SpookyCoin SpookyCoin && \
    mkdir -p /etc/services.d/SpookyCoind/log && \
    mkdir -p /var/log/SpookyCoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/SpookyCoind/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/SpookyCoind/run && \
    echo "cd /var/lib/SpookyCoind" >> /etc/services.d/SpookyCoind/run && \
    echo "export HOME /var/lib/SpookyCoind" >> /etc/services.d/SpookyCoind/run && \
    echo "s6-setuidgid SpookyCoind /usr/local/bin/SpookyCoind" >> /etc/services.d/SpookyCoind/run && \
    chmod +x /etc/services.d/SpookyCoind/run && \
    chown nobody:nogroup /var/log/SpookyCoind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/SpookyCoind/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/SpookyCoind/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/SpookyCoind" >> /etc/services.d/SpookyCoind/log/run && \
    chmod +x /etc/services.d/SpookyCoind/log/run && \
    echo "/var/lib/SpookyCoind true SpookyCoind 0644 0755" > /etc/fix-attrs.d/SpookyCoind-home && \
    echo "/home/SpookyCoin true SpookyCoin 0644 0755" > /etc/fix-attrs.d/SpookyCoin-home && \
    echo "/var/log/SpookyCoind true nobody 0644 0755" > /etc/fix-attrs.d/SpookyCoind-logs

VOLUME ["/var/lib/SpookyCoind", "/home/SpookyCoin","/var/log/SpookyCoind"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/SpookyCoin export HOME /home/SpookyCoin s6-setuidgid SpookyCoin /bin/bash"]
