#!/bin/bash

# Preparation
echo "Preparing..."
echo "First install the dkms module"
# Check kernel version
dkms_status=$(dkms status)
if [[ $dkms_status =~ "apple-bce 0.1" ]]; then
    echo "Uninstalling old modules..."
    sudo dkms uninstall -m apple-bce -v 0.1
    sudo dkms uninstall -m apple-ibridge -v 0.1
    sudo rm -r /usr/src/apple-bce-0.1
    sudo rm -r /usr/src/apple-ibridge-0.1
    sudo rm -r /var/lib/dkms/apple-bce
    sudo rm -r /var/lib/dkms/apple-ibridge
fi

# Installation
echo "Installing BCE (Buffer Copy Engine) module for Keyboard and Audio..."
if [ "$(uname)" == "Linux" ]; then
    sudo git clone https://github.com/t2linux/apple-bce-drv /usr/src/apple-bce-r183.c884d9c
    sudo tee /usr/src/apple-bce-r183.c884d9c/dkms.conf > /dev/null <<EOF
PACKAGE_NAME="apple-bce"
PACKAGE_VERSION="r183.c884d9c"
MAKE[0]="make KVERSION=\$kernelver"
CLEAN="make clean"
BUILT_MODULE_NAME[0]="apple-bce"
DEST_MODULE_LOCATION[0]="/kernel/drivers/misc"
AUTOINSTALL="yes"
EOF
    sudo dkms install -m apple-bce -v r183.c884d9c
fi

echo "Installing Touchbar and Ambient Light sensor modules..."
sudo git clone https://github.com/t2linux/apple-ib-drv /usr/src/apple-ibridge-0.1
sudo dkms install -m apple-ibridge -v 0.1

# Load modules
echo "Loading modules into the kernel..."
sudo modprobe apple_bce
sudo modprobe apple_ib_tb
sudo modprobe apple_ib_als

# Making the modules load at boot time
echo "Configuring modules to load at boot time..."
echo "apple-bce" | sudo tee -a /etc/modules-load.d/t2.conf > /dev/null
echo "apple-ib_tb" | sudo tee -a /etc/modules-load.d/t2.conf > /dev/null
echo "apple-ib-als" | sudo tee -a /etc/modules-load.d/t2.conf > /dev/null
echo "brcmfmac" | sudo tee -a /etc/modules-load.d/t2.conf > /dev/null

# Configuring the Touchbar module
echo "Configuring the Touchbar module..."
echo "options apple-ib-tb fnmode=1" | sudo tee /etc/modprobe.d/apple-tb.conf > /dev/null

# Fixing suspend
echo "Fixing suspend..."
sudo tee /lib/systemd/system-sleep/rmmod_tb.sh > /dev/null <<'EOF'
#!/bin/sh
if [ "${1}" = "pre" ]; then
  modprobe -r apple_ib_tb hid_apple
elif [ "${1}" = "post" ]; then
  modprobe hid_apple apple_ib_tb
fi
EOF
sudo chmod 755 /lib/systemd/system-sleep/rmmod_tb.sh
sudo chown root:root /lib/systemd/system-sleep/rmmod_tb.sh

# Possible Issues
echo "Fixing possible issues..."
sudo sh -c "echo 'blacklist apple-ib-als' >> /etc/modprobe.d/blacklist.conf"
