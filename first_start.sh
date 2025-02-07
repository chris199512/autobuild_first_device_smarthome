#!/bin/bash
set -e

# Function for formatting the SD card
format_sd_card() {
    print_message "SD card is being formatted..."
    for partition in $(lsblk -lno NAME | grep "^$(basename "$sd_card")"); do
        mount_point=$(findmnt -n -o TARGET "/dev/$partition" 2>/dev/null || true)
        if [ -n "$mount_point" ]; then
            print_message "Unmounting $mount_point"
            sudo umount "$mount_point"
        fi
    done
    sudo mkfs.vfat -F 32 "/dev/$sd_card" -n "RPiOS" -I
    print_message "SD card has been successfully formatted."
}

# Function for installing Raspberry Pi OS on the SD card
install_raspberry_pi_os() {
    print_message "Raspberry Pi OS is installed on $sd_card..."
    sudo dd bs=4M if="$image_path" of="/dev/$sd_card" conv=fsync status=progress
    print_message "Raspberry Pi OS has been successfully installed."
}

# Function for copying the setup script
copy_setup_script() {
    print_message "Setup script is copied..."
    # Check whether the directory is already mounted
    if findmnt -rno TARGET "$mount_path" >/dev/null; then
        print_message "$mount_path is already mounted, will now be unmounted."
        sudo umount "$mount_path"
    fi
    sudo mkdir -p "$mount_path"
    sudo mount "/dev/$sd_card"p2 "$mount_path"
    sudo cp "$setup_path" "$mount_path""$setup_path"
    sudo cp "$semaphore_config_path" "$mount_path""$semaphore_config_path"
    sudo cp "$setup_service_path" "$mount_path/etc/systemd/system/"
    print_message "Setup script was copied successfully."
    print_message "Create symbolic link to activate the setup service..."
    sudo ln -s "$mount_path/etc/systemd/system/$setup_service_name" "$mount_path/etc/systemd/system/multi-user.target.wants/$setup_service_name"
    print_message "Setup script and setup service file have been successfully copied."
    # Unmounting the directory
    sudo umount "$mount_path"
}

print_message() {
    echo "================================"
    echo "$1"
    echo "================================"
}

main() {
    sd_card="mmcblk0"
    setup_service_name="setup.service"
    image_path="/usr/local/sbin/os.img"
    mount_path="/media/sd"
    setup_path="/usr/local/sbin/setup.sh"
    setup_service_path="/usr/local/sbin/$setup_service_name"
    semaphore_config_path="/usr/local/sbin/semaphore_config.sh"
    
    sleep 20
    print_message "Script first_start.sh is executed"
    sleep 20
    format_sd_card
    install_raspberry_pi_os
    copy_setup_script

    print_message "Done. The system will restart in 10 seconds."
    sleep 10
    sudo reboot
}

main
