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

sudo qm destroy $VMID || true
sudo qm create $VMID --name "ubuntu-resolute-template" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0
sudo qm importdisk $VMID resolute-server-cloudimg-amd64-resized.img $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit

storage_property() {
    local property="$1"

    sudo awk -v storage="$SNIPPET_STORAGE" -v property="$property" '
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
    *) sudo pvesm set "$SNIPPET_STORAGE" --content "$SNIPPET_CONTENT,snippets" ;;
esac

SNIPPET_DIR="$SNIPPET_ROOT/snippets"
sudo install -d -m 0755 "$SNIPPET_DIR"

cat << EOF | sudo tee "$SNIPPET_DIR/ubuntu-resolute.yaml"
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

echo "timezone: "$(cat /etc/timezone) | sudo tee -a "$SNIPPET_DIR/ubuntu-resolute.yaml"
echo "locale: "$LANG | sudo tee -a "$SNIPPET_DIR/ubuntu-resolute.yaml"

sudo qm set $VMID --cicustom "vendor=$SNIPPET_STORAGE:snippets/ubuntu-resolute.yaml"
sudo qm set $VMID --tags ubuntu-template,resolute,cloudinit
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp,ip6=dhcp
sudo qm template $VMID
