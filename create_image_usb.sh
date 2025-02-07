#!/bin/bash
set -e

# Check whether all necessary files exist
check_required_files() {
  for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      print_message "Error: File $file does not exist."
      exit 1
    fi
  done
}

create_os_image() {
  chmod +x $CREATE_OS_IMAGE_SCRIPT_NAME
  ./"$CREATE_OS_IMAGE_SCRIPT_NAME" $OS_IMAGE_NAME $IMAGE_URL
}

download_raspbian_image() {
  wget -O image_usb.img.xz $IMAGE_URL
  unxz image_usb.img.xz
  IMAGE_FILE=$(ls ./*usb.img)
}

# Create a new image file
create_and_customize_image() {
  cp "$IMAGE_FILE" "$IMAGE_NAME"
  # Resize the image
  truncate -s +2G "$IMAGE_NAME"
}

mount_and_resize_partitions() {
  # Mount image partitions
  LOOP_DEV=$(losetup -f --show "$IMAGE_NAME")
  kpartx -av "$LOOP_DEV"
  # Resize the partitions
  partprobe "$LOOP_DEV"
  parted "$LOOP_DEV" resizepart 2 100% 
  # Notify the kernel of the partition changes
  kpartx -u "$LOOP_DEV"
  BOOT_DEV=$(echo "$LOOP_DEV" | sed 's/\/dev\//\/dev\/mapper\//')p1
  ROOT_DEV=$(echo "$LOOP_DEV" | sed 's/\/dev\//\/dev\/mapper\//')p2
  e2fsck -f -y "$ROOT_DEV"
  resize2fs "$ROOT_DEV"
  mkdir -p "$BOOT_PARTITION" "$ROOT_PARTITION"
  mount "$BOOT_DEV" "$BOOT_PARTITION"
  mount "$ROOT_DEV" "$ROOT_PARTITION"
}

create_userconf() {
  # Create userconf file on the boot partition
  PASSWORD="example"
  HASHED_PASSWORD=$(echo -n "$PASSWORD" | openssl passwd -6 -stdin)
  echo "example:$HASHED_PASSWORD" >> "$BOOT_PARTITION/userconf"
}

copy_files_and_configure_system() {
  # Check available space before copying files
  df -h "$ROOT_PARTITION"
  # Copy files to image
  cp -r $FIRST_START_SERVICE_NAME "$ROOT_PARTITION/etc/systemd/system"
  for file in "${FILES_TO_COPY[@]}"; do
    cp -r "$file" "$ROOT_PARTITION/usr/local/sbin"
  done
  # Set permissions
  chmod +x "$ROOT_PARTITION/usr/local/sbin/$FIRST_START_SCRIPT_NAME"
  # Copy qemu-arm-static for ARM emulation
  cp /usr/bin/qemu-aarch64-static "$ROOT_PARTITION/usr/bin/"
  # Configure language and keyboard layout
  echo "LANG=de_DE.UTF-8" > "$ROOT_PARTITION/etc/default/locale"
  echo "de_DE.UTF-8 UTF-8" > "$ROOT_PARTITION/etc/locale.gen"
  echo "KEYMAP=de" > "$ROOT_PARTITION/etc/vconsole.conf"
  echo 'XKBLAYOUT="de"' > "$ROOT_PARTITION/etc/default/keyboard"
  # Add user admin with password admin
  chroot "$ROOT_PARTITION" /usr/bin/qemu-aarch64-static /bin/bash <<EOF
locale-gen de_DE.UTF-8
update-locale LANG=de_DE.UTF-8
useradd -m -s /bin/bash $ADMIN_USER_NAME
echo "$ADMIN_USER_NAME:$ADMIN_USER_NAME" | chpasswd
systemctl enable $FIRST_START_SERVICE_NAME

# Grant admin sudo privileges
usermod -aG sudo $ADMIN_USER_NAME

# Delete pi User
deluser -r pi
deluser -r example

# Set up SSH key authentication
mkdir -p /home/$ADMIN_USER_NAME/.ssh
echo "$SSH_KEY" > /home/$ADMIN_USER_NAME/.ssh/authorized_keys
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

cleanup() {
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

main() {
  # Variables
  IMAGE_NAME="first_boot_usb.img"
  CREATE_OS_IMAGE_SCRIPT_NAME="create_os_image.sh"
  IMAGE_URL="https://downloads.raspberrypi.org/raspios_lite_arm64_latest"
  OS_IMAGE_NAME="os.img"
  FIRST_START_SERVICE_NAME="first_start.service"
  FIRST_START_SCRIPT_NAME="first_start.sh"
  SETUP_SERVICE_NAME="setup.service"
  SETUP_SCRIPT_NAME="setup.sh"
  SEMAPHORE_CONFIG_SCRIPT_NAME="semaphore_config.sh"
  ADMIN_USER_NAME="admin"
  SSH_KEY="FILL_ME"
  MOUNT_DIR="/mnt/rpi"
  BOOT_PARTITION="${MOUNT_DIR}/boot"
  ROOT_PARTITION="${MOUNT_DIR}/root"
  REQUIRED_FILES=("$FIRST_START_SERVICE_NAME" "$FIRST_START_SCRIPT_NAME" "$SETUP_SERVICE_NAME" "$SETUP_SCRIPT_NAME" "$CREATE_OS_IMAGE_SCRIPT_NAME" "$SEMAPHORE_CONFIG_SCRIPT_NAME")
  FILES_TO_COPY=("$FIRST_START_SCRIPT_NAME" "$SETUP_SERVICE_NAME" "$SETUP_SCRIPT_NAME" "$SEMAPHORE_CONFIG_SCRIPT_NAME" "$OS_IMAGE_NAME")

  check_required_files
  create_os_image
  download_raspbian_image
  create_and_customize_image
  mount_and_resize_partitions
  create_userconf
  copy_files_and_configure_system
  cleanup
  print_message "Image successfully created and customized."
}

main
