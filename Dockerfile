FROM debian:stable-slim as builder
ARG CABAL_VERSION=3.6.2.0
ARG GHC_VERSION=8.10.7

WORKDIR /code

# system dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && \
  apt-get install -y \
    automake \
    build-essential \
    pkg-config \
    libffi-dev \
    libgmp-dev \
    libnuma-dev \
    libpq-dev \
    libssl-dev \
    libsystemd-dev \
    libtinfo-dev \
    llvm-dev \
    zlib1g-dev \
    make \
    g++ \
    tmux \
    git \
    jq \
    wget \
    libncursesw5 \
    libtool \
    autoconf

# cabal
ENV CABAL_VERSION=${CABAL_VERSION}
ENV PATH="/root/.cabal/bin:/root/.ghcup/bin:/root/.local/bin:$PATH"
RUN wget https://downloads.haskell.org/~cabal/cabal-install-${CABAL_VERSION}/cabal-install-${CABAL_VERSION}-$(uname -m)-linux-deb10.tar.xz \
    && tar -xf cabal-install-${CABAL_VERSION}-$(uname -m)-linux-deb10.tar.xz \
    && rm cabal-install-${CABAL_VERSION}-$(uname -m)-linux-deb10.tar.xz \
    && mkdir -p ~/.local/bin \
    && mv cabal ~/.local/bin/ \
    && cabal update && cabal --version

# GHC
ENV GHC_VERSION=${GHC_VERSION}
RUN wget https://downloads.haskell.org/~ghc/${GHC_VERSION}/ghc-${GHC_VERSION}-$(uname -m)-deb10-linux.tar.xz \
    && tar -xf ghc-${GHC_VERSION}-$(uname -m)-deb10-linux.tar.xz \
    && rm ghc-${GHC_VERSION}-$(uname -m)-deb10-linux.tar.xz \
    && cd ghc-${GHC_VERSION} \
    && ./configure \
    && make install

# Libsodium
RUN git clone https://github.com/input-output-hk/libsodium && \
    cd libsodium && \
    git checkout 66f017f1 && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

# secp256k1
RUN git clone https://github.com/bitcoin-core/secp256k1 && \
    cd secp256k1 && \
    git checkout ac83be33 && \
    ./autogen.sh && \
    ./configure --enable-module-schnorrsig --enable-experimental && \
    make && \
    make install

FROM builder as cardano-db-sync-build
# Install cardano-db-sync
ARG DBSYNC_VERSION=13.1.0.1
ENV DBSYNC_VERSION=${DBSYNC_VERSION}
RUN echo "Building tags/${DBSYNC_VERSION}..." \
    && echo tags/${DBSYNC_VERSION} > /CARDANO_BRANCH \
    && git clone https://github.com/input-output-hk/cardano-db-sync.git \
    && cd cardano-db-sync\
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout tags/${DBSYNC_VERSION} \
    && cabal configure --with-compiler=ghc-$GHC_VERSION \
    && cabal build cardano-db-sync \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-$GHC_VERSION/cardano-db-sync-${DBSYNC_VERSION}/build/cardano-db-sync/cardano-db-sync /root/.local/bin/ \
    && rm -rf /root/.cabal/packages \
    && rm -rf /usr/local/lib/ghc-8.10.7/ /usr/local/share/doc/ghc-8.10.7/ \
    && rm -rf /code/cardano-db-sync/dist-newstyle/ \
    && rm -rf /root/.cabal/store/ghc-8.10.7

FROM debian:stable-slim as cardano-db-sync
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
COPY --from=cardano-db-sync-build /usr/local/lib/ /usr/local/lib/
COPY --from=cardano-db-sync-build /usr/local/include/ /usr/local/include/
COPY --from=cardano-db-sync-build /root/.local/bin/cardano-* /code/cardano-db-sync/scripts/postgresql-setup.sh /usr/local/bin/
COPY --from=cardano-db-sync-build /code/cardano-db-sync/schema/ /opt/cardano/schema/
COPY bin/ /bin/
COPY config/ /opt/cardano/config/
RUN apt-get update -y && \
  apt-get install -y \
    libffi7 \
    libgmp10 \
    libncursesw5 \
    libnuma1 \
    libsystemd0 \
    libssl1.1 \
    libtinfo6 \
    llvm-11-runtime \
    pkg-config \
    postgresql-client \
    zlib1g && \
  chmod +x /usr/local/bin/* && \
  rm -rf /var/lib/apt/lists/*
EXPOSE 8080
ENTRYPOINT ["/bin/entry-point"]
