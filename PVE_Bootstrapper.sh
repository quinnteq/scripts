#!/bin/bash

echo "Starting Quinton's PVE Bootstrapper!"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Step 1: Update the system to the latest patches
echo "Updating the system to the latest patches..."
apt update && apt full-upgrade -y

# Step 2: Remove the Proxmox license nag
echo "Removing the Proxmox license nag..."
sed -i.bak "s/^/#/" /usr/share/perl5/PVE/API2/Subscription.pm

# Step 3: Update to the non-production Proxmox repository
echo "Configuring non-production Proxmox repositories..."
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.list
deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription
EOF
apt update

# Step 4: Optional AMT Serial Console Setup
read -p "Do you want to configure Intel AMT serial console settings? (y/n): " CONFIGURE_AMT
if [[ "$CONFIGURE_AMT" =~ ^[Yy]$ ]]; then
  read -p "Enter the serial port to use (default ttyS4): " SERIAL_PORT
  SERIAL_PORT=${SERIAL_PORT:-ttyS4}
  cat <<EOL > /etc/systemd/system/serial-getty@$SERIAL_PORT.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -L $SERIAL_PORT 115200 vt100
EOL
  systemctl daemon-reload
  systemctl restart serial-getty@$SERIAL_PORT.service
  echo "Serial console configured on $SERIAL_PORT with vt100 emulation."
else
  echo "Skipping Intel AMT serial console configuration."
fi

# Step 5: Set timezone and enable NTP
read -p "Enter your timezone (e.g., 'America/New_York'): " TIMEZONE
timedatectl set-timezone "$TIMEZONE"
apt install -y chrony
systemctl enable chrony && systemctl start chrony

# Step 6: Install common tools
apt install -y htop curl wget net-tools fail2ban mailutils

# Step 7: Configure Fail2Ban for SSH
systemctl enable fail2ban && systemctl start fail2ban

# Step 8: Enable unattended security upgrades
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Step 9: Email for system notifications
echo "root: admin@ceresstation.gay" >> /etc/aliases
newaliases

# Reboot the system to apply changes
echo "Configuration complete. Rebooting to apply all changes."
reboot
