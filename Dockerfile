FROM ghcr.io/blinklabs-io/haskell:9.6.3-3.10.2.0-1 AS cardano-db-sync-build
RUN apt-get update && apt-get install -y libpq-dev
# Install cardano-db-sync
ARG DBSYNC_VERSION=13.4.1.0
ENV DBSYNC_VERSION=${DBSYNC_VERSION}
ARG DBSYNC_REF=tags/13.4.1.0
ENV DBSYNC_REF=${DBSYNC_REF}
ARG DBTOOL_VERSION=13.4.1.0
ENV DBTOOL_VERSION=${DBTOOL_VERSION}
RUN echo "Building ${DBSYNC_REF}..." \
    && echo ${DBSYNC_REF} > /CARDANO_DB_SYNC_REF \
    && git clone https://github.com/input-output-hk/cardano-db-sync.git \
    && cd cardano-db-sync\
    && git fetch --all --recurse-submodules --tags \
    && git tag \
    && git checkout ${DBSYNC_REF} \
    && cabal update \
    && cabal configure --with-compiler=ghc-${GHC_VERSION} \
    && cabal build cardano-db-sync \
    && cabal build cardano-db-tool \
    && mkdir -p /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/cardano-db-sync-${DBSYNC_VERSION}/build/cardano-db-sync/cardano-db-sync /root/.local/bin/ \
    && cp -p dist-newstyle/build/$(uname -m)-linux/ghc-${GHC_VERSION}/cardano-db-tool-${DBTOOL_VERSION}/x/cardano-db-tool/build/cardano-db-tool/cardano-db-tool /root/.local/bin/ \
    && rm -rf /root/.cabal/packages \
    && rm -rf /usr/local/lib/ghc-${GHC_VERSION}/ /usr/local/share/doc/ghc-${GHC_VERSION}/ \
    && rm -rf /code/cardano-db-sync/dist-newstyle/ \
    && rm -rf /root/.cabal/store/ghc-${GHC_VERSION}

FROM ghcr.io/blinklabs-io/cardano-configs:20240725-1 AS cardano-configs

FROM debian:bookworm-slim AS cardano-db-sync
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
COPY --from=cardano-db-sync-build /usr/local/lib/ /usr/local/lib/
COPY --from=cardano-db-sync-build /usr/local/include/ /usr/local/include/
COPY --from=cardano-db-sync-build /root/.local/bin/cardano-* /code/cardano-db-sync/scripts/postgresql-setup.sh /usr/local/bin/
COPY --from=cardano-db-sync-build /code/cardano-db-sync/schema/ /opt/cardano/schema/
COPY --from=cardano-configs /config/ /opt/cardano/config/
COPY bin/ /bin/
RUN apt-get update -y && \
  apt-get install -y \
    curl \
    libffi8 \
    libgmp10 \
    libncursesw5 \
    libnuma1 \
    libsystemd0 \
    libssl3 \
    libtinfo6 \
    llvm-14-runtime \
    pkg-config \
    postgresql-client \
    zlib1g && \
  chmod +x /usr/local/bin/* && \
  rm -rf /var/lib/apt/lists/*
EXPOSE 8080
ENTRYPOINT ["/bin/entry-point"]
