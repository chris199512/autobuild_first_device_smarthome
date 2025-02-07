#!/bin/bash
set -e

download_image(){
# Download Raspbian image
wget -O image_system.img.xz "$IMAGE_URL"
unxz image_system.img.xz
OS_IMAGE_FILE=$(ls ./*system.img)
}

create_os_image(){
# Create a new image file
cp "$OS_IMAGE_FILE" "$OS_IMAGE_NAME"

# Mount image partitions
LOOP_DEV=$(losetup -f --show "$OS_IMAGE_NAME")
kpartx -av "$LOOP_DEV"

BOOT_DEV=$(echo "$LOOP_DEV" | sed 's/\/dev\//\/dev\/mapper\//')p1
ROOT_DEV=$(echo "$LOOP_DEV" | sed 's/\/dev\//\/dev\/mapper\//')p2
mkdir -p "$BOOT_PARTITION" "$ROOT_PARTITION"
mount "$BOOT_DEV" "$BOOT_PARTITION"
mount "$ROOT_DEV" "$ROOT_PARTITION"
}

add_arm_emulation(){
# Copy qemu-arm-static for ARM emulation
cp /usr/bin/qemu-aarch64-static "$ROOT_PARTITION/usr/bin/"
}

create_userconf() {
  # Create userconf file on the boot partition
  PASSWORD="example"
  HASHED_PASSWORD=$(echo -n "$PASSWORD" | openssl passwd -6 -stdin)
  echo "example:$HASHED_PASSWORD" > "$BOOT_PARTITION/userconf"
}

modifie_os_image(){
# Configure language and keyboard layout
echo "LANG=de_DE.UTF-8" > "$ROOT_PARTITION/etc/default/locale"
echo "de_DE.UTF-8 UTF-8" > "$ROOT_PARTITION/etc/locale.gen"
echo "KEYMAP=de" > "$ROOT_PARTITION/etc/vconsole.conf"
echo 'XKBLAYOUT="de"' > "$ROOT_PARTITION/etc/default/keyboard"

# Set hostname
echo "$HOSTNAME" > "$ROOT_PARTITION/etc/hostname"
echo "127.0.1.1   $HOSTNAME" >> "$ROOT_PARTITION/etc/hosts"

# shellcheck disable=SC2154
# Add user admin-local with password
chroot "$ROOT_PARTITION" /usr/bin/qemu-aarch64-static /bin/bash <<EOF
locale-gen de_DE.UTF-8
update-locale LANG=de_DE.UTF-8
useradd -m -s /bin/bash $ADMIN_USER_NAME
echo "$ADMIN_USER_NAME:$ADMIN_PW" | chpasswd

# Grant admin sudo privileges
usermod -aG sudo $ADMIN_USER_NAME

# Delete pi User
deluser -r pi
deluser -r example

# Set up SSH key authentication
mkdir -p /home/$ADMIN_USER_NAME/.ssh
EOF
for ssh_key in "${SSH_KEYS[@]}"; do
    echo "$ssh_key" >> "$ROOT_PARTITION/home/$ADMIN_USER_NAME/.ssh/authorized_keys"
done
chroot "$ROOT_PARTITION" /usr/bin/qemu-aarch64-static /bin/bash <<EOF
chmod 700 /home/$ADMIN_USER_NAME/.ssh
chmod 600 /home/$ADMIN_USER_NAME/.ssh/authorized_keys
chown -R $ADMIN_USER_NAME:$ADMIN_USER_NAME /home/$ADMIN_USER_NAME/.ssh

# Disable password authentication for SSH and root login
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl enable ssh

apt-get clean
EOF
}

cleanup(){
# Clean up
umount "$BOOT_PARTITION"
umount "$ROOT_PARTITION"
kpartx -d "$LOOP_DEV"
losetup -d "$LOOP_DEV"
rmdir "$BOOT_PARTITION" "$ROOT_PARTITION"
}

print_message() {
    echo "================================"
    echo "$1"
    echo "================================"
}

main(){
# Variables
OS_IMAGE_NAME="$1"
IMAGE_URL="$2"

MOUNT_DIR="/mnt/os"
BOOT_PARTITION="${MOUNT_DIR}/boot"
ROOT_PARTITION="${MOUNT_DIR}/root"
HOSTNAME="FILL-ME"
ADMIN_USER_NAME="FILL-ME"
ADMIN_PW="FILL-ME"
SSH_KEYS=("FILL-ME" "FILL-ME")

download_image
create_os_image
add_arm_emulation
create_userconf
modifie_os_image
cleanup

print_message "$OS_IMAGE_NAME successfully created."
}

main "$@"
