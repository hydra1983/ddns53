#!/bin/bash

# Install dependencies
apt-get update
apt-get -y install python-pip sed curl ntp
ntpdate ntp.ubuntu.com

pip install boto --upgrade

curl -sSL https://github.com/hydra1983/ddns53/raw/master/etc/init.d/ddns53.sh > /etc/init.d/ddns53
chmod +x /etc/init.d/ddns53
/etc/init.d/ddns53 start
update-rc.d ddns53 defaults