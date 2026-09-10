locals {
  repository_ssh_public_key_directory = "${path.module}/../../../keys"
  repository_ssh_public_key_files     = sort(fileset(local.repository_ssh_public_key_directory, "*.pub"))
  repository_ssh_public_keys = [
    for key_file in local.repository_ssh_public_key_files :
    trimspace(file("${local.repository_ssh_public_key_directory}/${key_file}"))
    if trimspace(file("${local.repository_ssh_public_key_directory}/${key_file}")) != ""
  ]

  vm_ssh_authorized_keys = distinct(concat(
    [trimspace(file(pathexpand(var.ssh_public_key_file)))],
    local.repository_ssh_public_keys
  ))

  # The private half exists only on Ops during the first Ansible run. It solves
  # the initial key-distribution cycle, then Ansible removes it after installing
  # Ops' permanent management key on every guest.
  ops_bootstrap_ssh_public_key = trimspace(tls_private_key.ops_bootstrap.public_key_openssh)
  workload_ssh_authorized_keys = distinct(concat(
    local.vm_ssh_authorized_keys,
    [local.ops_bootstrap_ssh_public_key]
  ))
}
