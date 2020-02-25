# TeslaCamFileServer
A Raspberry Pi project to playback TeslaCam Sentry Mode videos directly on the Tesla Car Browser, using ideas from (marcone / teslausb) + (billz / raspap-webgui) + (BobStrogg / teslacam-browser) + https://sentrycam.appspot.com/
------------------
What is needed:

- Raspberry Pi Zero W or Raspberry Pi 4
- An sdcard with at least 16GB space
- Time and patience :D

------------------

Download the [latest release of Raspbian](https://www.raspberrypi.org/downloads/raspbian/) (currently Buster). Raspbian Buster Lite is recommended.

Burn the image with [Rufus](https://rufus.ie/) or a software of your preference

Open the newly created sdcard's boot drive and remove the content ```init=/usr/lib/raspi-config/init_resize.sh``` from cmdline.txt

Add ```dtoverlay=dwc2``` to the end of config.txt

Create an empty ssh file (without any file extension) on boot partition

Create wpa_supplicant.conf on boot partition (the file must have Unix EOL "end of line" format),
alternativly you could duplicate cmdline.txt and rename it (keep in mind sometimes in windows the .txt extension is not shown)

In this new empty conf file insert your wifi credential:
```
country=it
update_config=1
ctrl_interface=/var/run/wpa_supplicant

network={
 scan_ssid=1
 ssid="wifi ap"
 psk="password"
}

network={
 scan_ssid=1
 ssid="phone tether ap"
 psk="password"
}
```
you can put as many network={} as you need, ssid and psk are inside quotes

Remove the sdcard, put it in your raspberry pi, and after it boots, ssh into it with [putty](https://www.putty.org/)

- username: pi
- password: raspberry

first we add usb gadget support for the raspberry pi
```
echo "dwc2" | sudo tee -a /etc/modules
echo "libcomposite" | sudo tee -a /etc/modules
```

Then we need to resize the root partition manually:
```
sudo fdisk /dev/mmcblk0
```
while in 
```
Command (m for help):
```
press p to print current partition table

the output should be something like
```
Device         Boot  Start     End Sectors  Size Id Type
/dev/mmcblk0p1        8192  532479  524288  256M  c W95 FAT32 (LBA)
/dev/mmcblk0p2      532480 4390911 3858432  1.9G 83 Linux
```

write down the start sector of /dev/mmcblk0p2 in the example its 532480

now delete the root partition by presssing d
```
Partition number (1,2, default 2):
```
default 2

create the new root partition by pressing n
```
Partition type
   p   primary (1 primary, 0 extended, 3 free)
   e   extended (container for logical partitions)
Select (default p):
```
press p
```
Partition number (2-4, default 2):
```
press 2
now insert the start sector we just wrote down (532480)
and the new end sector
we'll create a 4Gb partition
```
+4G
```
```
Created a new partition 2 of type 'Linux' and of size 4 GiB.
Partition #2 contains a ext4 signature.

Do you want to remove the signature? [Y]es/[N]o: n
```
press n to keep the current ext4 signature

press p and print out the new partition table
```
/dev/mmcblk0p2      532480 8921087 8388608    4G 83 Linux
```
write down the end sector of the root partition 
8921087 and add 1 = 8921088
this is the new start sector of our new partition where we'll save our sentrymode videos

create the new primary partition of size 6G of type b(Win95 FAT32)
to change partition type press t, select partition number (3), 
then b for WIN95 FAT32
```
/dev/mmcblk0p1         8192   532479   524288  256M  c W95 FAT32 (LBA)
/dev/mmcblk0p2       532480  8921087  8388608    4G 83 Linux
/dev/mmcblk0p3      8921088 21503999 12582912    6G  b W95 FAT32
```
create another primary partition of the remaining space,
in the example, the start sector is 21503999 + 1 = 21504000
```
/dev/mmcblk0p1          8192    532479    524288  256M  c W95 FAT32 (LBA)
/dev/mmcblk0p2        532480   8921087   8388608    4G 83 Linux
/dev/mmcblk0p3       8921088  21503999  12582912    6G  b W95 FAT32
/dev/mmcblk0p4      21504000 125026303 103522304 49.4G  b W95 FAT32
```
this is the end partition table
now press w to write to disk

its time to resync the root partition filesystem and reboot with these commands:
```
sudo resize2fs /dev/mmcblk0p2
sudo reboot
```

now we need to mount the usb gadget to the windows system or linux system
```
sudo modprobe g_mass_storage lux=2 file=/dev/mmcblk0p3,/dev/mmcblk0p4 stall=0 ro=0 removable=1 iSerialNumber=123456
```

now on your pc install [MiniTool Partition Wizard Free](https://www.partitionwizard.com/free-partition-manager.html) or use Gparted on linux
to partition and format those new partitions in FAT32

i haven't found a way to do it directly on the raspberry pi, because it can't write a partition inside a partition, if anyone know how to do it, leave a comment, tank you.

TODO: explain how to partition with partittion wizard free

---

Create folder ```TeslaCam``` in the 6GB drive

and ```savepoint``` in the other drive

-----

back to your pi console, we need to auto start the usb mount
```
sudo nano /lib/systemd/system/gmassstorage.service
```
write this content:
```
[Unit]
Description=Auto start modprobe g_mass_storage
After=multi-user.target

[Service]
ExecStart=sudo modprobe g_mass_storage file=/dev/mmcblk0p3 stall=0 ro=0 removable=1 iSerialNumber=123456

[Install]
WantedBy=multi-user.target
```
```ctrl + o``` to write to file
and ```ctrl + x``` to exit nano text editor

```
sudo systemctl daemon-reload
sudo systemctl enable gmassstorage.service
```

at this point, the raspberry pi works just like a usb stick, if you want to be sure all went well till now, try putting your newly created raspberry pi in your Car and check if the car can read and write to the drive.

---

now it's time to install all the apps, but first, let's change the default pi password for security reasons
```
sudo raspi-config
```
update and upgrade, go get a coffe :D
```
sudo apt-get update
sudo apt-get full-upgrade
```

---
install [billz/raspap-webgui](https://github.com/billz/raspap-webgui), its a better way to edit wifi and access point.
```
sudo curl -sL https://install.raspap.com | bash -s -- --yes
```
let's change the default port of raspap from 80 to 8080
```
sudo nano /etc/lighttpd/lighttpd.conf
```
change the server.port:
```
server.port                 = 8080
```
now access [http://raspberrypi:8080/](http://raspberrypi:8080/), from a browser, if it doesn't work, use ip address of the raspberry pi

- username: admin
- password: secret

go to [Configure hotspot](http://raspberrypi:8080/index.php?page=hostapd_conf) and activate the raspi access point
- in Basic tab: change SSID to you liking, mine is Morty :D 
- Wireless Mode: 802.11n -2.4 GHz
- in Security: change PSK
- in Advanced tab: activate WiFi client AP mode, select your country and save. make sure the "WiFi client AP mode" remains activated after changing tab.
if all went well start the hotspot

now change the raspap admin password in [Configure Auth](http://raspberrypi:8080/index.php?page=auth_conf)

you could also change the username if needed.

now you should see the newly create access point on other devices
---

time to add an public ip address to our pi for internal use; the Tesla browser blocks all lan connections, that's why we need a fake public ip address
```
sudo nano /etc/rc.local
```
add the following line before  ```exit 0```
```
sudo ifconfig lo:1 93.1.1.1 netmask 255.255.255.255 up
```
i'm using 93.1.1.1 here but it can be any pubblic ip address you want. (you'll loose the possibility to connect to the real ip)

let's also add a alternative hostname
```
sudo nano /etc/hosts
```
and add something like
```
93.1.1.1        myteslapicam.org
```

---

now for the system mount points that later our file server uses:
```
sudo mkdir /tslausb
sudo chmod -R 777 /tslausb
sudo chown -R pi:users /tslausb
sudo mkdir /savetsla
sudo chmod -R 777 /savetsla
sudo chown -R pi:users /savetsla
```
and automount it on start up
```
sudo nano /etc/fstab
```
add this content at the end
```
/dev/mmcblk0p3  /tslausb        vfat    loop,offset=1048576,nofail,uid=1000,gid=1000,umask=007  0       2
/dev/mmcblk0p4  /savetsla       vfat    loop,offset=1048576,nofail,uid=1000,gid=1000,umask=007  0       2
```

#Nodejs and pi zero w
---
for raspberry pi 4 use [this](#nodejs-and-pi-4)

let's install nodejs with the help of [sdesalas/node-pi-zero](https://github.com/sdesalas/node-pi-zero)
```
wget -O - https://raw.githubusercontent.com/sdesalas/node-pi-zero/master/install-node-v.last.sh | bash
```
Add support for node CLI tools
```
echo "export PATH=$PATH:/opt/nodejs/bin" | sudo tee -a ~/.profile
```
check installation by
```
node -v
npm -v
```
lastly install npx for reactjs
```
sudo npm i -g npx
```
check installation
```
npx -v
```
#Nodejs and pi 4
---
let's install nodejs for pi 4

for raspberry pi zero w use [this](#nodejs-and-pi-zero-w)
```
curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
https://nodejs.org/dist/v12.15.0/node-v12.15.0-linux-arm64.tar.xz
sudo apt install nodejs
```
check installation by
```
node -v
npm -v
```
lastly install npx for reactjs
```
sudo npm i -g npx
```
check installation
```
npx -v
```

#Install ffmpeg 
---
```
sudo apt-get intall ffmpeg 
```
#Install pm2
---
```
npm install -g pm2
```
#Install TeslaCamFileServer
---
```
cd ~
git clone https://github.com/WRXTsla/TeslaCamFileServer.git
```
```
cd ~/TeslaCamFileServer
npm install
pm2 start server.js
```
use pm2 to autostart the server at boot
```
pm2 startup
```
copy the command that is generated, should be
```
sudo env PATH=$PATH:/opt/nodejs/bin /opt/nodejs/lib/node_modules/pm2/bin/pm2 startup systemd -u pi --hp /home/pi
```
```
pm2 save
```
at this point the server should auto start at boot time.

attach the raspberry pi to the car, open up phone tether, and connect the car to the raspap wifi.

open car browser, and type in http://93.1.1.1:8084

when you need to watch lates video clips,
press Remount Source wait 2 seconds.
press Fix and copy video source; On the raspberry pi zero w, since it has a less powerfull cpu, the process will be pretty slow, it can take up to 5 minuts dipending on how many new video clips there are to be fixed.
anyway you can start loading videos while it's working in the background.

for the youtube fullscreen hack, you just press the button, you will be redirected to youtube, then press "go to site" and you are back to the app.

things needed in the next update:
- delete fold files that has already been fixed. since the first drive has only 6GB of space. it will fill up quite quickly.
- auto installer bash script

That's all for the moment.

