locals {
  ops_ssh_public_key_file = "${path.module}/keys/ops-management.pub"

  vm_ssh_authorized_keys = concat(
    [trimspace(file(pathexpand(var.ssh_public_key_file)))],
    fileexists(local.ops_ssh_public_key_file) ? [trimspace(file(local.ops_ssh_public_key_file))] : []
  )
}
