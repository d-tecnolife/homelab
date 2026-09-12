# SSH public keys

Place one OpenSSH public key per `*.pub` file in this directory. Terraform
adds them to newly created VMs, and the Ops SSH bootstrap playbook adds them
to existing VMs. Never store private keys here.

These are human workstation keys only. Machine keys do not belong here: Ops
generates its own management key during `bootstrap-ops-ssh.yml` and installs
it on every VM itself, and on Gateway through the API in
`gateway-authorize-ops.yml`. A committed copy of such a key cannot help --
the key is regenerated on rebuild, so the copy only goes stale while
continuing to authorize a private half no current host uses.
