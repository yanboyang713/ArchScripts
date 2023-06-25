#!/usr/bin/env bash

# Declare globle variable
SCRIPTFILE=${0##*/}
PRINTERFILE="printer.sh"
GLOBALFILE="global_var.sh"
user_shell="/bin/zsh"

source /root/$PRINTERFILE
source /root/$GLOBALFILE

set_zoneinfo()
{
    print_message ">>> Linking zoneinfo <<<"

    # Display the time zone
    echo "Default Time Zone: $ZONEINFO. Check /usr/share/zoneinfo/ for more options"

    read -r -p "Enter your Time Zone (press enter for default: $ZONEINFO): " timezone < /dev/tty
    # Set default value if name is empty
    timezone=${timezone:-$ZONEINFO}

    ln -s /usr/share/zoneinfo/$timezone /etc/localtime -f
}

enable_utc()
{
    print_message ">>> Setting time <<<"
    hwclock --systohc --utc
}

set_language()
{
    print_message ">>> Setting language and keymap <<<"

    # Set language
    default_language="en_US"
    echo "Default Language: $default_language. Check /etc/locale.gen for more options"

    read -r -p "Enter your language (press enter for default: $default_language): " language < /dev/tty

    # Set default value if name is empty
    language=${language:-$default_language}
    # Set value
    sed -i "s/#\($language\.UTF-8\)/\1/" /etc/locale.gen
    echo "LANG=$language.UTF-8" > /etc/locale.conf

    # Set keymap
    default_keymap="us"
    echo "Default Keymap: $default_keymap. Check /usr/share/kbd/keymaps/**/*.map.gz for more options"

    read -r -p "Enter your keymap (press enter for default: $default_keymap): " keymap < /dev/tty

    # Set default value if name is empty
    keymap=${keymap:-$default_keymap}

    echo "KEYMAP=$keymap" > /etc/vconsole.conf
    locale-gen
}

set_hostname()
{
    print_message ">>> Creating hostname <<<"

    read -r -p "Enter your hostname (press enter for default: Meta-Scientific-Linux): " hostname < /dev/tty

    # Set default value if name is empty
    hostname=${hostname:-Meta-Scientific-Linux}

    echo $hostname > /etc/hostname
}

enable_networking()
{
    print_message ">>> Enabling networking <<<"

    if [[ $(pacman -Qsq networkmanager) ]]; then
        systemctl enable NetworkManager.service
    else
        systemctl enable systemd-networkd.service
        systemctl enable systemd-resolved.service
    fi
}

enable_desktop_manager()
{
    print_message ">>> Enabling display manager <<<"

    if [[ $(pacman -Qsq sddm) ]]; then
        systemctl enable sddm.service
    elif [[ $(pacman -Qsq gdm) ]]; then
        systemctl enable gdm.service
    fi
}

setup_shell(){
    read -r -p "Enter your shell (press enter for default: /bin/zsh): " user_shell < /dev/tty
    # Set default value if name is empty
    user_shell=${user_shell:-"/bin/zsh"}

    # set shell
    chsh -s $user_shell
}

setup_account(){

    # username and password input
    print_message ">>> Meta Scientific using bitwarden manage your account and password <<<"
    print_message ">>> Your email alias will your username <<<"
    print_message ">>> Your root and user's password will be your bitwarden Master password <<<"

    read -r -p "Enter your bitwarden username: " username < /dev/tty
    read -r -p "Enter your bitwarden master password: " password < /dev/tty

    # root account
    print_message ">>> Setting root account and shell <<<"

    setup_shell

    print_message ">>> Done set root shell to $user_shell <<<"
    # This is insecure AF, don't use this if your machine is being monitored
    echo "root:$password" | chpasswd
    print_message ">>> Done set root password <<<"

    # user account
    print_message ">>> Creating $username account and set the Shell as $user_shell <<<"

    useradd -m -G wheel -s $user_shell $username

    # This is insecure AF, don't use this if your machine is being monitored
    echo "$username:$password" | chpasswd

    print_message ">>> Enabling sudo for $username <<<"
    sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\ALL\)/\1/' /etc/sudoers

    print_message ">>> Done create $username user with sudo, password and shell <<<"

    #print_message ">>> Moving AUR Helper instalation script to user folder <<<"

    #mv /root/yay_install.sh /home/$USERNAME/ -v
    #chown $USERNAME:$USERNAME /home/$USERNAME/yay_install.sh -v
}

install_grub()
{
    print_message ">>> Installing grub bootloader <<<"

    grub-install $(findmnt / -o SOURCE | tail -n 1 | awk -F'[0-9]' '{ print $1 }') --force
    grub-mkconfig -o /boot/grub/grub.cfg
}

install_refind()
{
    print_message ">>> Installing refind bootloader <<<"

    # Bait refind-install into thinking that a refind install already exists,
    # so it will "upgrade" (install) in desired location /boot/EFI/refind
    # This is done to avoid moving Microsoft's original bootloader.

    # Comment the following two lines if you have an HP computer
    # (suboptimal EFI implementation), or you don't mind moving
    # the original bootloader.
    mkdir -p /boot/EFI/refind
    cp /usr/share/refind/refind.conf-sample /boot/EFI/refind/refind.conf

    refind-install
    REFIND_UUID=$(cat /etc/fstab | grep UUID | grep "/ " | cut --fields=1)
    echo "\"Boot using default options\"     \"root=${REFIND_UUID} rw add_efi_memmap initrd=intel-ucode.img initrd=amd-ucode.img initrd=initramfs-linux.img" > /boot/refind_linux.conf
    echo "\"Boot using fallback initramfs\"  \"root=${REFIND_UUID} rw add_efi_memmap initrd=intel-ucode.img initrd=amd-ucode.img initrd=initramfs-linux-fallback.img" >> /boot/refind_linux.conf
    echo "\"Boot to terminal\"               \"root=${REFIND_UUID} rw add_efi_memmap initrd=intel-ucode.img initrd=amd-ucode.img initrd=initramfs-linux.img systemd.unit=multi-user.target" >> /boot/refind_linux.conf
}

install_bootloader()
{
    if [[ $(pacman -Qsq grub) ]]; then
        install_grub
    elif [[ $(pacman -Qsq refind) ]]; then
        install_refind
    fi
}

clean_up()
{
    print_success ">>> Ready! Cleaning up <<<"

    rm $GLOBALFILE -vf
    rm $PRINTERFILE -vf
    rm $SCRIPTFILE -vf
}

main()
{
    # Update repository
    pacman -Sy
    set_zoneinfo &&
    enable_utc &&
    set_language &&
    set_hostname &&
    enable_networking &&
    enable_desktop_manager &&
    setup_account &&
    install_bootloader &&
    clean_up
}

# Execute main
main
