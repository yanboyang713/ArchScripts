#!/usr/bin/env bash

SCRIPTFILE=${0##*/}
MOUNTPOINT="/mnt"

BASEDIR=$(readlink -f ${0%/*})
RECIPESDIR="${BASEDIR}/recipes"

PRINTERFILE="printer.sh"
CONFFILE="config.sh"
YAYFILE="yay_install.sh"
DISKFILE="disk.sh"

PRINTERPATH="${BASEDIR}/${PRINTERFILE}"
CONFPATH="${BASEDIR}/${CONFFILE}"
YAYPATH="${BASEDIR}/${YAYFILE}"

# --------------------------------------- #

# Use this for OFFLINE installation (ArchISOMaker)
CACHEDIR="/root/pkg"
PACMANPATH="${BASEDIR}/pacman_custom.conf"

# Use this if for ONLINE installation
#CACHEDIR="${MOUNTPOINT}/var/cache/pacman/pkg"
#PACMANPATH="/etc/pacman.conf"

# --------------------------------------- #

source $PRINTERPATH

select_base_packages()
{
    print_message "Selecting base packages..."

    source "${RECIPESDIR}/base/minimal.sh"
    export PACKAGES="${PACKAGES} ${RECIPE_PKGS}"

    source "${RECIPESDIR}/base/utilities.sh"
    export PACKAGES="${PACKAGES} ${RECIPE_PKGS}"
}

select_desktop_environment()
{
    print_message "Selecting Desktop Environment..."

    # Set keymap
    default_desktop_environment="i3"
    print_message "Default Desktop Environment: $default_desktop_environment. You also could choose kde, gnome, i3, x11"

    read -r -p "Enter your Desktop Environment (press enter for default: $default_desktop_environment): " desktop_environment < /dev/tty

    # Set default value if name is empty
    desktop_environment=${desktop_environment:-$default_desktop_environment}

    source "${RECIPESDIR}/desktops/${desktop_environment}.sh"
    export PACKAGES="${PACKAGES} ${RECIPE_PKGS}"
}

select_bootloader()
{
    print_message "Selecting bootloader..."

    # Set bootloader
    default_bootloader="grub"
    print_message "Default bootloader: $default_bootloader. You also could choose refind, grub"

    read -r -p "Enter your bootloader (press enter for default: $default_bootloader): " bootloader < /dev/tty

    # Set default value if name is empty
    bootloader=${bootloader:-$default_bootloader}

    source "${RECIPESDIR}/bootloaders/${bootloader}.sh"
    export PACKAGES="${PACKAGES} ${RECIPE_PKGS}"
}

select_video_drivers()
{
    print_message "Selecting xorg drivers..."

    # Set xorg drivers
    default_xorg_drivers="all"
    print_message "Default xorg driver: $default_xorg_drivers. You also could choose nvidia, amd, vbox, intel, all"

    read -r -p "Enter your xorg driver (press enter for default: $default_xorg_drivers): " xorg_drivers < /dev/tty

    # Set default value if name is empty
    xorg_drivers=${xorg_drivers:-$default_xorg_drivers}

    source "${RECIPESDIR}/video_drivers/${xorg_drivers}.sh"
    export PACKAGES="${PACKAGES} ${RECIPE_PKGS}"
}

install_packages()
{
    print_message "Installing packages..."
    pacstrap -C $PACMANPATH $MOUNTPOINT $PACKAGES --cachedir=$CACHEDIR --needed
}

generate_fstab()
{
    genfstab -p -U $MOUNTPOINT > $MOUNTPOINT/etc/fstab
}

copy_scripts()
{
    cp $CONFPATH $MOUNTPOINT/root -v
    cp $PRINTERPATH $MOUNTPOINT/root -v
    cp $YAYPATH $MOUNTPOINT/root -v
}

configure_system()
{
    print_warning ">>> Configuring your system ... <<<"
    arch-chroot $MOUNTPOINT /bin/zsh -c "cd && ./$CONFFILE && rm $CONFFILE -f"
}

check_mounted_drive() {
    if [[ $(findmnt -M "$MOUNTPOINT") ]]; then
        print_success "Drive mounted in $MOUNTPOINT."
    else
        print_failure "Drive is NOT MOUNTED!"
        print_warning "Mount your drive in '$MOUNTPOINT' and re-run '$SCRIPTFILE' to install your system."
        exit 1
    fi
}

install_system()
{
    select_base_packages
    select_desktop_environment
    select_bootloader
    select_video_drivers

    install_packages
    generate_fstab
    copy_scripts

    configure_system
}

verify_installation()
{
    [[ ! -f $MOUNTPOINT/root/$CONFFILE && ! -f $MOUNTPOINT/root/$PRINTERFILE ]]
}

disk_format_mount(){
    source $DISKFILE
}

main()
{
    # Disk format and mount
    disk_format_mount

    # Check pre-install state
    check_mounted_drive

    # Install and verify
    install_system
    verify_installation

    # Message at end
    if [[ $? == 0 ]]; then
        print_success "Installation finished! You can reboot now."
    else
        print_failure "Installation failed! Check errors before trying again."
        exit 1
    fi
}

# Execute main
main $@
