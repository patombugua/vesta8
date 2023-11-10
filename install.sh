#!/bin/sh -x
dnf update -y --skip-broken;
curl -O https://nginx.org/keys/nginx_signing.key;
rpm --import ./nginx_signing.key;
rm -fv "/etc/yum.repos.d/CentOS-CR.repo";
rm -fv "/etc/yum.repos.d/CentOS-Debuginfo.repo";
rm -fv "/etc/yum.repos.d/CentOS-fasttrack.repo";
rm -fv "/etc/yum.repos.d/CentOS-Media.repo";
rm -fv "/etc/yum.repos.d/CentOS-Sources.repo";
rm -fv "/etc/yum.repos.d/CentOS-Vault.repo";
rm -fv "/etc/yum.repos.d/CentOS-centosplus.repo";
dnf install epel-release -y --skip-broken;
dnf install -y http://rpms.famillecollet.com/enterprise/remi-release-9.rpm;
dnf update -y --skip-broken;
rm -fv /etc/yum.repos.d/remi-gl*;
rm -fv /etc/yum.repos.d/remi-php*;
wget raw.githubusercontent.com/patombugua/vesta8/master/remi8.repo -O /etc/yum.repos.d/remi.repo;
wget raw.githubusercontent.com/patombugua/vesta8/master/CentOS-PowerTools.repo -O /etc/yum.repos.d/CentOS-PowerTools.repo;
wget raw.githubusercontent.com/patombugua/vesta8/master/php873.repo -O /etc/yum.repos.d/php82.repo;
wget raw.githubusercontent.com/patombugua/vesta8/master/CentOS8-AppStream.repo -O /etc/yum.repos.d/CentOS-AppStream.repo;
wget raw.githubusercontent.com/patombugua/vesta8/master/remi8-safe.repo -O /etc/yum.repos.d/remi-safe.repo;
wget raw.githubusercontent.com/patombugua/vesta8/master/remi8-modular.repo -O /etc/yum.repos.d/remi-modular.repo;
dnf update -y --skip-broken;
useradd --shell=/usr/sbin/nologin spamd;
cd && wget http://raw.githubusercontent.com/patombugua/vesta8/master/centos8.sh -O /root/centos8.sh;
dos2unix centos8.sh;
sed -i 's/\r$//' centos8.sh;
chmod 7777 centos8.sh;
bash centos8.sh --nginx yes --apache yes --phpfpm no --named yes --remi yes --vsftpd yes --proftpd no --iptables no --fail2ban no --quota no --exim yes --dovecot yes --spamassassin yes --clamav no --softaculous no --mysql yes --postgresql no --force;
