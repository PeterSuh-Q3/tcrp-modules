#!/bin/bash
#
# Inject modules detected
#

function listextension() {

    if [ ! -z $1 ]; then
        echo "Searching for matching extension for $1"
        /usr/sbin/modprobe ${1}
        sleep 1
        if [ `/sbin/lsmod |grep -i ${1}|wc -l` -gt 0 ] ; then
            echo "Module ${1} loaded succesfully"
        else
            /usr/sbin/insmod /lib/modules/${1}.ko
        fi
    else
        echo "No matching extension"
    fi

}

function matchpciidmodule() {

    vendor="$(echo $1 | sed 's/[a-z]/\U&/g')"
    device="$(echo $2 | sed 's/[a-z]/\U&/g')"
    
    pciid="${vendor}d0000${device}"

    matchedmodule=$(jq -e -r ".modules[] | select(.alias | contains(\"${pciid}\")?) | .name " $MODULE_ALIAS_FILE)

    # Call listextensions for extention matching

    listextension $matchedmodule

}

function listpci() {

# Appears after 5 bytes, except for v1000,r1000,denverton platforms in Junior.

    lspci | while read line; do
    
        class="$(echo $line | sed -n 's/^.*Class \([[:xdigit:]]\{4\}\):.*$/\1/p')"
        vendor="$(echo $line | sed -n 's/^.*Device \([[:xdigit:]]\{4\}\):.*$/\1/p')"
        device="$(echo $line | sed -n 's/^.*Device \([[:xdigit:]]\{4\}\):\([[:xdigit:]]\{4\}\).*$/\2/p')"

        #echo "Class : $class Vendor: $vendor Device: $device"
        case $class in
        0100)
            echo "Found SCSI Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0106)
            echo "Found SATA Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0101)
            echo "Found IDE Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0104)
            echo "Found RAID bus Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0107)
            echo "Found SAS Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0200)
            echo "Found Ethernet Interface : pciid ${vendor}d0000${device} Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0680)
            echo "Found Ethernet Interface : pciid ${vendor}d0000${device} Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0300)
            echo "Found VGA Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        0c04)
            echo "Found Fibre Channel Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        esac
    done

}

function getvars() {

    TARGET_PLATFORM="$(uname -u | cut -d '_' -f2)"
    MODEL="$(uname -u | cut -d '_' -f3)"
    LINUX_VER="$(uname -r | cut -d '+' -f1)"
    
    echo $TARGET_PLATFORM
    echo $LINUX_VER
    case $TARGET_PLATFORM in

    bromolow)
        KERNEL_MAJOR="3"
        MODULE_ALIAS_FILE="modules.alias.3.json"
        ;;
    apollolake | broadwell | broadwellnk | v1000 | r1000 | denverton | geminilake | *)
        KERNEL_MAJOR="4"
        MODULE_ALIAS_FILE="modules.alias.4.json"
        ;;
    esac
    
    echo $MODULE_ALIAS_FILE
}

function virtio_modprobe() {
  echo "Checking for VirtIO"
  if (grep -r -q -E "(QEMU|VirtualBox)" /sys/devices/virtual/dmi/id/); then
    echo "VirtIO hypervisor detected"
    /usr/sbin/insmod /lib/modules/virtio.ko
    /usr/sbin/insmod /lib/modules/virtio_ring.ko
    /usr/sbin/insmod /lib/modules/virtio_mmio.ko
    /usr/sbin/insmod /lib/modules/virtio_pci.ko
    if [ "${LINUX_VER}" != "5.10.55" ]; then
    /usr/sbin/insmod /lib/modules/virtio_blk.ko
    /usr/sbin/insmod /lib/modules/virtio_net.ko
    /usr/sbin/insmod /lib/modules/virtio_scsi.ko
    fi
  else
    echo "*No* VirtIO hypervisor detected"
  fi
}

if [ "${1}" = "modules" ]; then
    getvars
    listpci
    virtio_modprobe
fi
