# SSH public keys

Place one OpenSSH public key per `*.pub` file in this directory. Terraform
adds them to newly created VMs, and the Ops SSH bootstrap playbook adds them
to existing VMs. Never store private keys here.
