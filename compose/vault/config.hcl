ui = true

storage "raft" {
  path    = "/vault/data"
  node_id = "apps-vault"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

# TLS is terminated by Caddy on Edge; do not publish this port beyond Apps.
api_addr     = "https://ssh-ca.dscim.dev"
cluster_addr = "http://127.0.0.1:8201"

# Integrated Storage recommends disabling mlock to avoid VM memory-lock limits.
disable_mlock = true
disable_cache = true
