# Weekly whole-VM image of Apps: a fast rollback after a bad update. It shares
# the Proxmox disk, so it is not disaster recovery; the nightly offsite backup
# in ansible/playbooks/app-data-backups.yml covers losing the host.
resource "proxmox_backup_job" "apps_weekly" {
  id             = "homelab-apps-weekly"
  node           = var.node_name
  schedule       = "sun 01:30"
  storage        = var.backup_datastore_id
  vmid           = [tostring(local.workload_catalog.apps.vm_id)]
  mode           = "snapshot"
  compress       = "zstd"
  enabled        = true
  repeat_missed  = true
  notes_template = "{{guestname}} weekly rollback image"
  prune_backups = {
    "keep-last" = "2"
  }

  depends_on = [proxmox_virtual_environment_vm.workload]
}
