#!/bin/bash
### BEGIN INIT INFO
# Provides:          ddns53
# Required-Start:    $syslog $local_fs $remote_fs $network $named
# Required-Stop:     $syslog $local_fs $remote_fs $network $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Register host to AWS Route53.
### END INIT INFO

########################################
#
#   Registers EC2 to Route 53
#
#   Requisition:
#       python-boto
#           https://github.com/boto/boto#installation
#       dig
#       awk
#       sed
#       grep
#       curl
#       cut
#
#   Install:
#       sudo apt-get update
#       sudo apt-get install python-pip sed curl
#       sudo pip install boto --upgrade
#       wget -O - https://gist.githubusercontent.com/hydra1983/5983758/raw/c4763017c53924b9421dfbbcef4615116ae156d0/ddns53 > ddns53 && sudo mv ddns53 /etc/init.d/
#
#       # Replace the values with your own
#       DDNS53_HOST_NAME=your host name
#       DDNS53_DOMAIN_NAME=your domain name
#       DDNS53_AWS_ACCESS_KEY_ID=your aws access key id
#       DDNS53_AWS_SECRET_ACCESS_KEY=your aws secret access key
#
#       cat /etc/init.d/ddns53 | sed "s/^HOSTNAME=.*/HOSTNAME=$DDNS53_HOST_NAME/" | sed "s/^DOMAIN=.*/DOMAIN=$DDNS53_DOMAIN_NAME/" | sed "s/^AWS_ACCESS_KEY_ID=.*/AWS_ACCESS_KEY_ID=$DDNS53_AWS_ACCESS_KEY_ID/" | sed "s/^AWS_SECRET_ACCESS_KEY=.*/AWS_SECRET_ACCESS_KEY=$DDNS53_AWS_SECRET_ACCESS_KEY/" | sudo tee /etc/init.d/ddns53 1>/dev/null
#       sudo chmod +x /etc/init.d/ddns53
#       cd /etc/init.d
#       sudo update-rc.d ddns53 defaults
#       sudo /etc/init.d/ddns53 start
#
#   Usage:
#       /etc/init.d/ddns53 start
#       /etc/init.d/ddns53 stop
#
#   References:
#       Adding EC2 instances to Route53
#           http://blog.ianbeyer.com/2012/09/11/adding-ec2-to-route53/
#       利用 Route 53 設定 Ec2 動態 DNS
#           http://blog.hsatac.net/2012/06/aws-ec2-setup-dynamic-dns-using-route-53/
#
#   Author:
#       Edison Guo
#           http://blog.hydra1983.com
########################################
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

HOSTNAME=<hostname>
DOMAIN=<domainname>
NEW_TTL=300

AWS_ACCESS_KEY_ID=<access key id>
AWS_SECRET_ACCESS_KEY=<secret access key>

IP_CHECK_URL="http://169.254.169.254/latest/meta-data/public-hostname"
DNS_SERVER=8.8.8.8

###############################################################
# You should not need to change anything beyond this point
###############################################################
export PATH=$PATH

AUTH_SERVER=$(dig NS @$DNS_SERVER $DOMAIN | grep -v ';' | grep -m 1 awsdns | grep $DOMAIN | awk '{print $(NF)}')
if [ "$AUTH_SERVER" = ""  ]; then
    echo The domain $DOMAIN not resolved by Amazon Route 53 name servers.
    exit 1
fi

export DOMAIN=$DOMAIN
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

ZONEID=`route53 ls | awk '($2 == "ID:"){printf "%s ",$3;getline;printf "%s\n",$3}' | grep $DOMAIN | awk '{print $1}'`

FULL_NAME="${HOSTNAME}.${DOMAIN}"
INUSE=`route53 get $ZONEID | grep $FULL_NAME | wc -l`

NEW_ADDR=`curl -s --fail $IP_CHECK_URL`

RECORD=$(dig @$AUTH_SERVER A $FULL_NAME | grep -v ";" | grep "$FULL_NAME")
OLD_TYPE=$( echo $RECORD | cut -d ' ' -f 4 )
OLD_ADDR=$( echo $RECORD | cut -d ' ' -f 5 | sed s/.$//)
OLD_TTL=$( echo $RECORD | cut -d ' ' -f 2 )

register() {
    RESULT=`route53 add_record $ZONEID $FULL_NAME CNAME $NEW_ADDR $NEW_TTL | grep "PENDING"`
    if [[ "$RESULT" == "" ]]; then
            echo "... failed.";
    else
            echo "... success.";
    fi
}

deregister() {
    RESULT=`route53 del_record $ZONEID $FULL_NAME CNAME $NEW_ADDR $NEW_TTL | grep "PENDING"`
    if [[ "$RESULT" == "" ]]; then
            echo "... failed.";
    else
            echo "... success.";
    fi
}

start() {
    echo "Registering host"

    if [ "$NEW_ADDR" = "$OLD_ADDR" ]; then
        echo "No need to register host to the same address"
        exit $?
    fi

    if [[ $INUSE > 0 ]]; then
        echo "Deregister old record"
        deregister
    fi

    echo "Register new record"
    register
}

stop() {
    echo "Deregistering host"

    if [[ $INUSE > 0 ]]; then
        echo "Deregister record"
        deregister
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: ddns53 {start|stop|restart}"
        exit 1
        ;;
esac
exit $?