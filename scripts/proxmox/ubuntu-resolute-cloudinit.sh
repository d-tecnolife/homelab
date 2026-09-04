#! /bin/bash

set -xe

VMID="${VMID:-9001}"
STORAGE="${STORAGE:-local-lvm}"
SNIPPET_STORAGE="${SNIPPET_STORAGE:-local}"

IMG="resolute-server-cloudimg-amd64.img"
BASE_URL="https://cloud-images.ubuntu.com/resolute/current"
EXPECTED_SHA=$(wget -qO- "$BASE_URL/SHA256SUMS" | awk '/'$IMG'/{print $1}')

download() {
    wget -q "$BASE_URL/$IMG"
}

verify() {
    sha256sum "$IMG" | awk '{print $1}'
}

[ ! -f "$IMG" ] && download

ACTUAL_SHA=$(verify)

if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
    rm -f "$IMG"
    download
    ACTUAL_SHA=$(verify)
    [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ] && exit 1
fi

rm -f resolute-server-cloudimg-amd64-resized.img
cp resolute-server-cloudimg-amd64.img resolute-server-cloudimg-amd64-resized.img
qemu-img resize resolute-server-cloudimg-amd64-resized.img 8G

qm destroy $VMID || true
qm create $VMID --name "ubuntu-resolute-template" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0
qm importdisk $VMID resolute-server-cloudimg-amd64-resized.img $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
qm set $VMID --boot order=virtio0
qm set $VMID --scsi1 $STORAGE:cloudinit

storage_property() {
    local property="$1"

    awk -v storage="$SNIPPET_STORAGE" -v property="$property" '
        /^[^[:space:]]+:[[:space:]]+/ { in_storage = ($2 == storage) }
        in_storage && $1 == property { print $2; exit }
    ' /etc/pve/storage.cfg
}

SNIPPET_CONTENT="$(storage_property content)"
SNIPPET_ROOT="$(storage_property path)"

if [ -z "$SNIPPET_CONTENT" ] || [ -z "$SNIPPET_ROOT" ]; then
    echo "Unable to resolve content types or path for snippet storage '$SNIPPET_STORAGE'." >&2
    exit 1
fi

case ",$SNIPPET_CONTENT," in
    *,snippets,*) ;;
    *) pvesm set "$SNIPPET_STORAGE" --content "$SNIPPET_CONTENT,snippets" ;;
esac

SNIPPET_DIR="$SNIPPET_ROOT/snippets"
install -d -m 0755 "$SNIPPET_DIR"

cat << EOF | tee "$SNIPPET_DIR/ubuntu-resolute.yaml"
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

echo "timezone: "$(cat /etc/timezone) | tee -a "$SNIPPET_DIR/ubuntu-resolute.yaml"
echo "locale: "$LANG | tee -a "$SNIPPET_DIR/ubuntu-resolute.yaml"

qm set $VMID --cicustom "vendor=$SNIPPET_STORAGE:snippets/ubuntu-resolute.yaml"
qm set $VMID --tags ubuntu-template,resolute,cloudinit
qm set $VMID --ciuser $USER
qm set $VMID --sshkeys ~/.ssh/authorized_keys
qm set $VMID --ipconfig0 ip=dhcp,ip6=dhcp
qm template $VMID
