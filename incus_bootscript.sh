#!/bin/bash

echo "Starting Incus bootscript..."

# Update package lists
# apt-get update

# Install necessary packages
# apt-get install -y git python3 python3-pip

mkdir -p /opt/log/
echo "Bootscript working..." > /opt/log/bootscript.log

echo "Incus bootscript completed."