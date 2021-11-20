#!/bin/bash

for i in `seq 4`; do
    sudo mkdir -p /mnt/disks/ssd$i; sudo chmod 777 /mnt/disks/ssd$i
done
