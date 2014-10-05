## Usage

* Add script below as ```user-data``` when create AWS EC2 instance

```shell
#!/bin/bash

#----------------------------------------
# Create config file for ddns53
#----------------------------------------
mkdir /etc/ddns53

cat <<EOF > /etc/ddns53/ddns53.conf
HOSTNAME=<instance host name>
DOMAIN=<instance domain>
AWS_ACCESS_KEY_ID=<aws access key id>
AWS_SECRET_ACCESS_KEY=<aws secret access key>

NEW_TTL=300
IP_CHECK_URL="http://169.254.169.254/latest/meta-data/public-hostname"
DNS_SERVER=8.8.8.8
EOF
```

* Install ddns53 

```shell
curl -sSL https://github.com/hydra1983/ddns53/raw/master/install.sh | sudo bash
```