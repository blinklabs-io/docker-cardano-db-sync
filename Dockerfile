FROM ghcr.io/blinklabs-io/haskell:8.10.7-3.6.2.0 as cardano-db-sync-build
RUN apt-get update && apt-get install -y libpq-dev
# Install cardano-db-sync
ARG DBSYNC_VERSION=13.1.0.2
ENV DBSYNC_VERSION=${DBSYNC_VERSION}
RUN echo "Building tags/${DBSYNC_VERSION}..." \
    && echo tags/${DBSYNC_VERSION} > /CARDANO_BRANCH \
    && git clone https://github.com/input-output-hk/cardano-db-sync.git \
    && cd cardano-db-sync\
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout tags/${DBSYNC_VERSION} \
    && cabal update \
    && cabal configure --with-compiler=ghc-${GHC_VERSION} \
    && cabal build cardano-db-sync \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/cardano-db-sync-${DBSYNC_VERSION}/build/cardano-db-sync/cardano-db-sync /root/.local/bin/ \
    && rm -rf /root/.cabal/packages \
    && rm -rf /usr/local/lib/ghc-${GHC_VERSION}/ /usr/local/share/doc/ghc-${GHC_VERSION}/ \
    && rm -rf /code/cardano-db-sync/dist-newstyle/ \
    && rm -rf /root/.cabal/store/ghc-${GHC_VERSION}

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
