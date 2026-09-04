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
}
