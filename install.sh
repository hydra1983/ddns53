apt-get update
apt-get install python-pip sed curl -y
pip install boto --upgrade
wget -O https://github.com/hydra1983/ddns53/raw/master/etc/init.d/ddns53.sh > /etc/init.d/ddns53
mkdir /etc/ddns53
wget -O https://github.com/hydra1983/ddns53/raw/master/etc/ddns53/ddns53.conf > /etc/ddns53/ddns53.conf
vi /etc/ddns53/ddns53.conf
chmod +x /etc/init.d/ddns53
update-rc.d ddns53 defaults
/etc/init.d/ddns53 start