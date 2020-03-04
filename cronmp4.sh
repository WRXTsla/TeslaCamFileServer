#!/bin/bash
sudo umount /tslausb
sudo umount /savetsla
sudo mount -a

find /tslausb/TeslaCam/ -type d | while IFS= read -r line; do [ ! -d /savetsla/savepoint/TeslaCam/${line#/tslausb/TeslaCam/} ] &&  mkdir /savetsla/savepoint/TeslaCam/${line#/tslausb/TeslaCam/}; done
find /tslausb/TeslaCam/ -type f -not -path "*RecentClips*" -iname "*.mp4" | while IFS= read -r line; do [ ! -f /savetsla/savepoint${line#/tslausb} ] && cd /savetsla/savepoint && ffmpeg -nostdin -i $line -c copy -err_detect ignore_err /savetsla/savepoint${line#/tslausb} ; done

exit 0