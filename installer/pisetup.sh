#!/bin/bash
var_revision=`sudo cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}'`
echo "=========add pi usb modules, disable hdmi, bluetooth and led========="
echo "dtoverlay=dwc2" | sudo tee -a /boot/config.txt
echo "dtoverlay=pi3-disable-bt" | sudo tee -a /boot/config.txt
echo "dtparam=act_led_trigger=none" | sudo tee -a /boot/config.txt
echo "dtparam=act_led_activelow=on" | sudo tee -a /boot/config.txt

echo "dwc2" | sudo tee -a /etc/modules
echo "libcomposite" | sudo tee -a /etc/modules
sudo apt-get install parted

echo "=========expand root partition and create two fat32 partitions========="
echo ",4G" | sudo sfdisk -w never -N 2 --force /dev/mmcblk0
sudo partprobe
sudo resize2fs /dev/mmcblk0p2
echo "9999,6G,b
9999,+,b" | sudo sfdisk -w never -a --force /dev/mmcblk0
sudo partprobe

echo "=========virtually partition and format fat32 partitions========="
rm ~/tmp.img
sudo losetup -D
var_sectors=$(sudo sfdisk -ls /dev/mmcblk0p3)
var_sectors=$(($var_sectors*2))
dd if=/dev/null of=~/tmp.img seek=$var_sectors count=0
echo ",+,b" | sfdisk tmp.img
sudo losetup -o1048576 /dev/loop3 ~/tmp.img
sudo losetup -a
sudo mkdosfs -F 32 -I /dev/loop3
sudo dd if=~/tmp.img of=/dev/mmcblk0p3 bs=1M count=15
rm ~/tmp.img
sudo losetup -D
var_sectors=$(sudo sfdisk -ls /dev/mmcblk0p4)
var_sectors=$(($var_sectors*2))
dd if=/dev/null of=~/tmp.img seek=$var_sectors count=0
echo ",+,b" | sfdisk tmp.img
sudo losetup -o1048576 /dev/loop3 ~/tmp.img
sudo losetup -a
sudo mkdosfs -F 32 -I /dev/loop3
sudo dd if=~/tmp.img of=/dev/mmcblk0p4 bs=1M count=15
sudo losetup -D
rm ~/tmp.img

echo "=========autostart modprobe g_mass_storage========="
echo "[Unit]
Description=Auto start modprobe g_mass_storage
After=multi-user.target

[Service]
ExecStart=sudo modprobe g_mass_storage file=/dev/mmcblk0p3 stall=0 ro=0 removable=1 iSerialNumber=123456

[Install]
WantedBy=multi-user.target" | sudo tee -a /lib/systemd/system/gmassstorage.service

sudo systemctl daemon-reload
sudo systemctl enable gmassstorage.service

echo "=========create mount points========="
sudo mkdir /tslausb
sudo chmod -R 777 /tslausb
sudo chown -R pi:users /tslausb
sudo mkdir /savetsla
sudo chmod -R 777 /savetsla
sudo chown -R pi:users /savetsla

echo "=========add fstab automount points========="
echo "/dev/mmcblk0p3  /tslausb        vfat    loop,offset=1048576,nofail,uid=1000,gid=1000,umask=007  0       2
/dev/mmcblk0p4  /savetsla       vfat    loop,offset=1048576,nofail,uid=1000,gid=1000,umask=007  0       2" | sudo tee -a /etc/fstab
sudo mount -a
mkdir /savetsla/savepoint
mkdir /tslausb/TeslaCam

sudo modprobe g_mass_storage file=/dev/mmcblk0p3 stall=0 ro=0 removable=1 iSerialNumber=123456

sudo apt-get update
#sudo apt-get -y full-upgrade
#sudo apt-get autoremove
#sudo apt-get autoclean

echo "=========update finished========="

echo "=========install nodejs========="
if [ "$var_revision" == "9000c1" ]; then 
   echo "=========for pi zero w========="
   wget -O - https://raw.githubusercontent.com/sdesalas/node-pi-zero/master/install-node-v.last.sh | sudo bash -
   wait
   echo "export PATH=$PATH:/opt/nodejs/bin" | sudo tee -a ~/.profile
   PATH=$PATH:/opt/nodejs/bin
   sudo apt-get install -y git
else
   echo "=========for pi 4========="
   curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
   wait
   sudo apt-get install -y nodejs
fi
node -v
npm -v
echo "=========Install npx========="
sudo npm install -g npx
wait
npx -v
echo "=========Install pm2========="
sudo npm install -g pm2
wait
pm2 -v

echo "=========Install ffmpeg========="
sudo apt-get -y install ffmpeg 

echo "=========Install TeslaCamFileServer========="
cd ~
git clone https://github.com/WRXTsla/TeslaCamFileServer.git
cd ~/TeslaCamFileServer
npm install
wait
pm2 start server.js
wait
pm2 startup | grep "sudo env PATH" | bash -
wait
pm2 save
cd ~

echo "=========install raspap========="
sudo curl -sL https://install.raspap.com | bash -s -- --yes

sudo sed -i -e 's/server.port                 = 80/server.port                 = 8080/g' /etc/lighttpd/lighttpd.conf
sudo sed -i -e '/^exit 0/i sudo ifconfig lo:1 93.1.1.1 netmask 255.255.255.255 up' /etc/rc.local
sudo sed -i -e '/^exit 0/i sudo service procps restart' /etc/rc.local
sudo sed -i -e '/^exit 0/i sudo /opt/vc/bin/tvservice -o' /etc/rc.local
echo "93.1.1.1        myteslapicam.org" | sudo tee -a /etc/hosts

echo "net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.eth0.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf


var_current_ip=$(hostname -I)
echo "
========================================================================
access the newly installed raspap at http://${var_current_ip%%*( )}/
with username: admin
and  password: secret

go to Configure hotspot
- in Basic tab: change SSID
- Wireless Mode: 802.11n -2.4 GHz
- in Security: change PSK
- in Advanced tab: activate WiFi client AP mode, select your country and save.
make sure the "WiFi client AP mode" remains activated after switching tabs.
- "Start hotspot"

- change the default admin password

for future access use port 8080 http://${var_current_ip%%*( )}:8080/
"
read -p "Press [Enter] key to continue..."

#write out current crontab
crontab -l > mycron
#echo new cron into cron file
echo "*/15 * * * * /boot/cronmp4.sh" >> mycron
#install new cron file
crontab mycron
rm mycron

read -p "Finished, remember to change default password using sudo raspi-config
Press [Enter] key to continue..."
sudo wpa_supplicant -B -Dnl80211,wext -c/etc/wpa_supplicant/wpa_supplicant.conf -iwlan0
