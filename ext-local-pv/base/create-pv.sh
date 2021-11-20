#!/bin/bash

node=$1
num=$2

rm ext-pv-${node}-pv*
for i in `seq $num`;do
    filename=ext-pv-$node-pv$i.yaml
    cp template.yaml $filename
    sed -i -e "s/name: template/name: ext-pv-${node}-pv${i}/" $filename
    sed -i -e "s#path: template#path: /mnt/disks/ssd${i}#" $filename
    sed -i -e "s/- template-hostname/- ${node}/" $filename
    sudo mkdir -p /mnt/disks/ssd$i; sudo chmod 777 /mnt/disks/ssd$i
    echo "- ${filename}"
done
