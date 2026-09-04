# Compose secrets

Store one encrypted environment file per stack here:

```text
secrets/compose/<stack>.sops.env
```

Start from the stack's committed `.env.example`, encrypt it with SOPS, and
commit only the encrypted result. `deploy-compose.yml` decrypts it in memory
and installs `/opt/compose/<stack>/.env` as `root:docker` mode `0640`.
