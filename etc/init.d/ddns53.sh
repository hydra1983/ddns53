#!/bin/bash
### BEGIN INIT INFO
# Provides:          ddns53
# Required-Start:    $syslog $local_fs $remote_fs $network $named
# Required-Stop:     $syslog $local_fs $remote_fs $network $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Register host to AWS Route53.
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

export PATH=$PATH

CONF=/etc/ddns53/ddns53.conf

if [[ -f $CONF ]] ; then
    source $CONF
else
    echo "$CONF is missing"
    exit 1
fi

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