# docker-cardano-db-sync

Builds a Cardano DB sync container from source on Debian. This image attempts
to keep interface compatibility with `inputoutput/cardano-db-sync`, but may
diverge slightly, particularly with any Nix-specific paths.

## Running

To run a Cardano DB sync on mainnet, attached to a local Cardano full node
container running:

```bash
docker run --detach \
  --name cardano-db-sync \
  -v dbsync-state:/var/lib/cexplorer \
  -v node-ipc:/node-ipc \
  ghcr.io/blinklabs-io/cardano-db-sync
```

DB sync logs can be followed:

```bash
docker logs -f cardano-db-sync
```
