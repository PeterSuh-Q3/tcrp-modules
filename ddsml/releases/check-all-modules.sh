#!/bin/bash
#
# Inject modules detected
#

listextension() {

    if [ ! -z $1 ]; then
        echo "Searching for matching extension for $1"

        # Priority 1: try _txrx/_tx variants first (multi-queue + RSS optimization)
        # so they bind to the PCI device before vanilla
        for suffix in _txrx _tx; do
            variant="${1}${suffix}"
            if [ -f "/lib/modules/${variant}.ko" ]; then
                echo "Loading variant first (priority): ${variant}"
                /usr/sbin/insmod "/lib/modules/${variant}.ko" 2>/dev/null
            fi
        done

        # Priority 2: load vanilla (will become idle if variant already claimed device)
        /usr/sbin/modprobe "${1}"

        # Wait for 2 seconds
        sleep 2

        # Check whether ANY variant (vanilla or _txrx/_tx) bound to the device
        if lspci -v | grep -qE "Kernel driver in use: (${1}|${1}_txrx|${1}_tx)"; then
            echo "Module ${1} (or variant) loaded successfully and is in use"
        else
            echo "Module ${1} not detected in use, trying insmod"
            /usr/sbin/insmod "/lib/modules/${1}.ko"
        fi
    else
        echo "No matching extension"
    fi

}

matchpciidmodule() {

    vendor="$(echo $1 | sed 's/[a-z]/\U&/g')"
    device="$(echo $2 | sed 's/[a-z]/\U&/g')"
    
    pciid="${vendor}d0000${device}"

    matchedmodule=$(jq -e -r ".modules[] | select(.alias | contains(\"${pciid}\")?) | .name " $MODULE_ALIAS_FILE)

    # Call listextensions for extention matching

    listextension $matchedmodule

}

listpci() {

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
            # Intel 내장 GPU는 misc 애드온에서 i915 패치 후 처리하므로 SKIP
            if [ "${vendor}" = "8086" ]; then
                echo "Skip Intel VGA Controller : pciid ${vendor}d0000${device} (handled by misc addon)"
            else
                echo "Found VGA Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            fi
            ;;
        0c04)
            echo "Found Fibre Channel Controller : pciid ${vendor}d0000${device}  Required Extension : $(matchpciidmodule ${vendor} ${device})"
            ;;
        esac
    done

}

getvars() {

    TARGET_PLATFORM="$(uname -a | awk '{print $NF}' | cut -d '_' -f2)"
    MODEL="$(uname -a | awk '{print $NF}' | cut -d '_' -f3)"
    LINUX_VER="$(uname -r | cut -d '+' -f1)"
    
    echo $TARGET_PLATFORM
    echo $LINUX_VER
    case $TARGET_PLATFORM in

    avoton | bromolow | braswell | cedarview | grantley)
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

# virtio_modprobe / mmc_modprobe / usblan_modprobe moved to
# etc-modules-load/src/install.sh so they run regardless of whether ddsml
# or eudev is the installed hardware-detection addon.

if [ "${1}" = "modules" ]; then
    echo "ddsml - ${1}"
    gunzip -c ./modules.alias.3.json.tgz | tar xvf -
    gunzip -c ./modules.alias.4.json.tgz | tar xvf -
    /usr/sbin/depmod -a
    # Pre-load LSI Fusion MPT base/scsi providers so PCI-triggered HBA drivers
    # (mptsas/mptspi/mpt3sas) resolve their mpt_*/mptscsih_* symbols even if
    # listextension falls back to a dependency-less insmod.
    /usr/sbin/modprobe scsi_transport_sas 2>/dev/null
    /usr/sbin/modprobe mptbase 2>/dev/null
    /usr/sbin/modprobe mptscsih 2>/dev/null
    getvars
    listpci
fi
