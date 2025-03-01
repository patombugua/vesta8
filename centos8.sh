#!/bin/bash

# Vesta RHEL/CentOS installer v.05

#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
export PATH=$PATH:/sbin
RHOST='r.vestacp.com'
CHOST='c.vestacp.com'
REPO='cmmnt'
VERSION='rhel'
VESTA='/usr/local/vesta'
memory=$(grep 'MemTotal' /proc/meminfo |tr ' ' '\n' |grep [0-9])
arch=$(uname -i)
os=$(cut -f 1 -d ' ' /etc/redhat-release)
release=$(grep -o "[0-9]" /etc/redhat-release |head -n1)
codename="${os}_7"
vestacp="$VESTA/install/$VERSION/7"

# Defining software pack for all distros
software="http://nginx.org/packages/mainline/centos/9/x86_64/RPMS/nginx-1.25.4-1.el9.ngx.x86_64.rpm awstats bc bind bind-libs bind-utils clamav-server clamav-update
    curl dovecot e2fsprogs exim expect fail2ban flex freetype ftp GeoIP httpd
    ImageMagick iptables-services jwhois lsof mailx mariadb mariadb-server mc
    mod_fcgid mod_ssl net-tools openssh-clients pcre php
    php-bcmath php-cli php-common php-fpm php-gd php-imap php-mbstring
    php-mcrypt phpMyAdmin php-mysql php-pdo phpPgAdmin php-pgsql php-soap
    php-tidy php-xml php-xmlrpc postgresql postgresql-contrib
    postgresql-server proftpd roundcubemail rrdtool rsyslog screen
    spamassassin sqlite sudo tar telnet unzip vesta vesta-ioncube vesta-nginx
    vesta-php vesta-softaculous vim-common vsftpd which zip"

# Fix for old releases
if [ "$release" -lt 7 ]; then
    software=$(echo "$software" |sed -e "s/mariadb/mysql/g")
    software=$(echo "$software" |sed -e "s/clamav-server/clamd/")
    software=$(echo "$software" |sed -e "s/clamav-update//")
    software=$(echo "$software" |sed -e "s/iptables-services//")
    software="$software mod_extract_forwarded"
fi

# Defining help function
help() {
    echo "Usage: $0 [OPTIONS]
  -a, --apache            Install Apache        [yes|no]  default: yes
  -n, --nginx             Install Nginx         [yes|no]  default: yes
  -w, --phpfpm            Install PHP-FPM       [yes|no]  default: no
  -v, --vsftpd            Install Vsftpd        [yes|no]  default: yes
  -j, --proftpd           Install ProFTPD       [yes|no]  default: no
  -k, --named             Install Bind          [yes|no]  default: yes
  -m, --mysql             Install MySQL         [yes|no]  default: yes
  -g, --postgresql        Install PostgreSQL    [yes|no]  default: no
  -d, --mongodb           Install MongoDB       [yes|no]  unsupported
  -x, --exim              Install Exim          [yes|no]  default: yes
  -z, --dovecot           Install Dovecot       [yes|no]  default: yes
  -c, --clamav            Install ClamAV        [yes|no]  default: yes
  -t, --spamassassin      Install SpamAssassin  [yes|no]  default: yes
  -i, --iptables          Install Iptables      [yes|no]  default: yes
  -b, --fail2ban          Install Fail2ban      [yes|no]  default: yes
  -r, --remi              Install Remi repo     [yes|no]  default: yes
  -o, --softaculous       Install Softaculous   [yes|no]  default: yes
  -q, --quota             Filesystem Quota      [yes|no]  default: no
  -l, --lang              Default language                default: en
  -y, --interactive       Interactive install   [yes|no]  default: yes
  -s, --hostname          Set hostname
  -e, --email             Set admin email
  -p, --password          Set admin password
  -f, --force             Force installation
  -h, --help              Print this help

  Example: bash $0 -e demo@sysdop.com -p p4ssw0rd --apache no --phpfpm yes"
    exit 1
}

# Defining password-gen function
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=10
    while [ ${n:=1} -le $LENGTH ]; do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done
    echo "$PASS"
}

# Defining return code check function
check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

# Defining function to set default value
set_default_value() {
    eval variable=\$$1
    if [ -z "$variable" ]; then
        eval $1=$2
    fi
    if [ "$variable" != 'yes' ] && [ "$variable" != 'no' ]; then
        eval $1=$2
    fi
}

# Defining function to set default language value
set_default_lang() {
    if [ -z "$lang" ]; then
        eval lang=$1
    fi
    lang_list="
        ar cz el fa hu ja no pt se ua
        bs da en fi id ka pl ro tr vi
        cn de es fr it nl pt-BR ru tw
        bg ko sr th ur"
    if !(echo $lang_list |grep -w $lang 1>&2>/dev/null); then
        eval lang=$1
    fi
}


#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --apache)               args="${args}-a " ;;
        --nginx)                args="${args}-n " ;;
        --phpfpm)               args="${args}-w " ;;
        --vsftpd)               args="${args}-v " ;;
        --proftpd)              args="${args}-j " ;;
        --named)                args="${args}-k " ;;
        --mysql)                args="${args}-m " ;;
        --postgresql)           args="${args}-g " ;;
        --mongodb)              args="${args}-d " ;;
        --exim)                 args="${args}-x " ;;
        --dovecot)              args="${args}-z " ;;
        --clamav)               args="${args}-c " ;;
        --spamassassin)         args="${args}-t " ;;
        --iptables)             args="${args}-i " ;;
        --fail2ban)             args="${args}-b " ;;
        --remi)                 args="${args}-r " ;;
        --softaculous)          args="${args}-o " ;;
        --quota)                args="${args}-q " ;;
        --lang)                 args="${args}-l " ;;
        --interactive)          args="${args}-y " ;;
        --hostname)             args="${args}-s " ;;
        --email)                args="${args}-e " ;;
        --password)             args="${args}-p " ;;
        --force)                args="${args}-f " ;;
        --help)                 args="${args}-h " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "a:n:w:v:j:k:m:g:d:x:z:c:t:i:b:r:o:q:l:y:s:e:p:fh" Option; do
    case $Option in
        a) apache=$OPTARG ;;            # Apache
        n) nginx=$OPTARG ;;             # Nginx
        w) phpfpm=$OPTARG ;;            # PHP-FPM
        v) vsftpd=$OPTARG ;;            # Vsftpd
        j) proftpd=$OPTARG ;;           # Proftpd
        k) named=$OPTARG ;;             # Named
        m) mysql=$OPTARG ;;             # MySQL
        g) postgresql=$OPTARG ;;        # PostgreSQL
        d) mongodb=$OPTARG ;;           # MongoDB (unsupported)
        x) exim=$OPTARG ;;              # Exim
        z) dovecot=$OPTARG ;;           # Dovecot
        c) clamd=$OPTARG ;;             # ClamAV
        t) spamd=$OPTARG ;;             # SpamAssassin
        i) iptables=$OPTARG ;;          # Iptables
        b) fail2ban=$OPTARG ;;          # Fail2ban
        r) remi=$OPTARG ;;              # Remi repo
        o) softaculous=$OPTARG ;;       # Softaculous plugin
        q) quota=$OPTARG ;;             # FS Quota
        l) lang=$OPTARG ;;              # Language
        y) interactive=$OPTARG ;;       # Interactive install
        s) servername=$OPTARG ;;        # Hostname
        e) email=$OPTARG ;;             # Admin email
        p) vpass=$OPTARG ;;             # Admin password
        f) force='yes' ;;               # Force install
        h) help ;;                      # Help
        *) help ;;                      # Print help (default)
    esac
done

# Defining default software stack
set_default_value 'nginx' 'yes'
set_default_value 'apache' 'yes'
set_default_value 'phpfpm' 'no'
set_default_value 'vsftpd' 'yes'
set_default_value 'proftpd' 'no'
set_default_value 'named' 'yes'
set_default_value 'mysql' 'yes'
set_default_value 'postgresql' 'no'
set_default_value 'mongodb' 'no'
set_default_value 'exim' 'yes'
set_default_value 'dovecot' 'yes'
if [ $memory -lt 1500000 ]; then
    set_default_value 'clamd' 'no'
    set_default_value 'spamd' 'no'
else
    set_default_value 'clamd' 'yes'
    set_default_value 'spamd' 'yes'
fi
set_default_value 'iptables' 'yes'
set_default_value 'fail2ban' 'yes'
set_default_value 'remi' 'yes'
set_default_value 'softaculous' 'yes'
set_default_value 'quota' 'no'
set_default_value 'interactive' 'yes'
set_default_lang 'en'

# Checking software conflicts
if [ "$phpfpm" = 'yes' ]; then
    apache='no'
    nginx='yes'
fi
if [ "$proftpd" = 'yes' ]; then
    vsftpd='no'
fi
if [ "$exim" = 'no' ]; then
    clamd='no'
    spamd='no'
    dovecot='no'
fi
if [ "$iptables" = 'no' ]; then
    fail2ban='no'
fi

# Checking root permissions
if [ "x$(id -u)" != 'x0' ]; then
    check_result 1 "Script can be run executed only by root"
fi

# Checking admin user account
if [ ! -z "$(grep ^admin: /etc/passwd /etc/group)" ] && [ -z "$force" ]; then
    echo 'Please remove admin user account before proceeding.'
    echo 'If you want to do it automatically run installer with -f option:'
    echo -e "Example: bash $0 --force\n"
    check_result 1 "User admin exists"
fi

# Checking wget
if [ ! -e '/usr/bin/wget' ]; then
    dnf -y install wget
    check_result $? "Can't install wget"
fi

# Checking repository availability
wget -q "c.vestacp.com/GPG.txt" -O /dev/null
check_result $? "No access to Vesta repository"

# Checking installed packages
tmpfile=$(mktemp -p /tmp)
rpm -qa > $tmpfile
for pkg in exim mysql-server httpd nginx vesta; do
    if [ ! -z "$(grep $pkg $tmpfile)" ]; then
        conflicts="$pkg $conflicts"
    fi
done
rm -f $tmpfile
if [ ! -z "$conflicts" ] && [ -z "$force" ]; then
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    echo 'Following packages are already installed:'
    echo "$conflicts"
    echo
    echo 'It is highly recommended to remove them before proceeding.'
    echo 'If you want to force installation run this script with -f option:'
    echo "Example: bash $0 --force"
    echo
    echo '!!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!! !!!'
    echo
    check_result 1 "Control Panel should be installed on clean server."
fi


#----------------------------------------------------------#
#                       Brief Info                         #
#----------------------------------------------------------#

# Printing nice ASCII logo
clear
echo
echo ' _|      _|  _|_|_|_|    _|_|_|  _|_|_|_|_|    _|_|'
echo ' _|      _|  _|        _|            _|      _|    _|'
echo ' _|      _|  _|_|_|      _|_|        _|      _|_|_|_|'
echo '   _|  _|    _|              _|      _|      _|    _|'
echo '     _|      _|_|_|_|  _|_|_|        _|      _|    _|'
echo
echo '                                  Vesta Control Panel'
echo -e "\n\n"

echo 'The following software will be installed on your system:'

# Web stack
if [ "$nginx" = 'yes' ]; then
    echo '   - Nginx Web Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo '   - Apache Web Server'
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo '   - Apache Web Server (as backend)'
fi
if [ "$phpfpm"  = 'yes' ]; then
    echo '   - PHP-FPM Application Server'
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo '   - Bind DNS Server'
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo -n '   - Exim Mail Server'
    if [ "$clamd" = 'yes'  ] ||  [ "$spamd" = 'yes' ] ; then
        echo -n ' + '
        if [ "$clamd" = 'yes' ]; then
            echo -n 'ClamAV '
        fi
        if [ "$spamd" = 'yes' ]; then
            echo -n 'SpamAssassin'
        fi
    fi
    echo
    if [ "$dovecot" = 'yes' ]; then
        echo '   - Dovecot POP3/IMAP Server'
    fi
fi

# Database stack
if [ "$mysql" = 'yes' ]; then
    if [ $release -ge 7 ]; then
        echo '   - MariaDB Database Server'
    else
        echo '   - MySQL Database Server'
    fi
fi
if [ "$postgresql" = 'yes' ]; then
    echo '   - PostgreSQL Database Server'
fi
if [ "$mongodb" = 'yes' ]; then
    echo '   - MongoDB Database Server'
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo '   - Vsftpd FTP Server'
fi
if [ "$proftpd" = 'yes' ]; then
    echo '   - ProFTPD FTP Server'
fi

# Softaculous
if [ "$softaculous" = 'yes' ]; then
    echo '   - Softaculous Plugin'
fi

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo -n '   - Iptables Firewall'
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo -n ' + Fail2Ban'
fi
echo -e "\n\n"

# Asking for confirmation to proceed
if [ "$interactive" = 'yes' ]; then
    read -p 'Would you like to continue [y/n]: ' answer
    if [ "$answer" != 'y' ] && [ "$answer" != 'Y'  ]; then
        echo 'Goodbye'
        exit 1
    fi

    # Asking for contact email
    if [ -z "$email" ]; then
        read -p 'Please enter admin email address: ' email
    fi

    # Asking to set FQDN hostname
    if [ -z "$servername" ]; then
        read -p "Please enter FQDN hostname [$(hostname -f)]: " servername
    fi
fi

# Generating admin password if it wasn't set
if [ -z "$vpass" ]; then
    vpass=$(gen_pass)
fi

# Set hostname if it wasn't set
if [ -z "$servername" ]; then
    servername=$(hostname -f)
fi

# Set FQDN if it wasn't set
mask1='(([[:alnum:]](-?[[:alnum:]])*)\.)'
mask2='*[[:alnum:]](-?[[:alnum:]])+\.[[:alnum:]]{2,}'
if ! [[ "$servername" =~ ^${mask1}${mask2}$ ]]; then
    if [ ! -z "$servername" ]; then
        servername="$servername.example.com"
    else
        servername="example.com"
    fi
    echo "127.0.0.1 $servername" >> /etc/hosts
fi

# Set email if it wasn't set
if [ -z "$email" ]; then
    email="admin@$servername"
fi

# Defining backup directory
vst_backups="/root/vst_install_backups/$(date +%s)"
echo "Installation backup directory: $vst_backups"

# Printing start message and sleeping for 5 seconds
echo -e "\n\n\n\nInstallation will take about 15 minutes ...\n"
sleep 5


#----------------------------------------------------------#
#                      Checking swap                       #
#----------------------------------------------------------#

# Checking swap on small instances
if [ -z "$(swapon -s)" ] && [ $memory -lt 1000000 ]; then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
fi


#----------------------------------------------------------#
#                   Install repository                     #
#----------------------------------------------------------#

# Updating system
dnf -y update
check_result $? 'dnf update failed'

# Installing EPEL repository
dnf install epel-release -y
check_result $? "Can't install EPEL repository"

# Installing Remi repository
if [ "$remi" = 'yes' ] && [ ! -e "/etc/yum.repos.d/remi.repo" ]; then
    rpm -Uvh http://rpms.remirepo.net/enterprise/remi-release-$release.rpm
    check_result $? "Can't install REMI repository"
    sed -i "s/enabled=0/enabled=1/g" /etc/yum.repos.d/remi.repo
fi

# Installing Nginx repository
nrepo="/etc/yum.repos.d/nginx.repo"
echo "[nginx]" > $nrepo
echo "name=nginx repo" >> $nrepo
echo "baseurl=http://nginx.org/packages/mainline/centos/9/x86_64/" >> $nrepo

# Installing Vesta repository
vrepo='/etc/yum.repos.d/vesta.repo'
echo "[vesta]" > $vrepo
echo "name=Vesta - $REPO" >> $vrepo
# echo "baseurl=http://$RHOST/" >> $vrepo
echo "baseurl=http://r.vestacp.com/cmmnt/8/x86_64/$basearch/" >> $vrepo
echo "enabled=1" >> $vrepo
echo "gpgcheck=0" >> $vrepo
echo "gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-VESTA" >> $vrepo
wget c.vestacp.com/GPG.txt -O /etc/pki/rpm-gpg/RPM-GPG-KEY-VESTA


#----------------------------------------------------------#
#                         Backup                           #
#----------------------------------------------------------#

# Creating backup directory tree
mkdir -p $vst_backups
cd $vst_backups
mkdir nginx httpd php php-fpm vsftpd proftpd named exim dovecot clamd \
    spamassassin mysql postgresql mongodb vesta

# Backup Nginx configuration
service nginx stop > /dev/null 2>&1
cp -r /etc/nginx/* $vst_backups/nginx > /dev/null 2>&1

# Backup Apache configuration
service httpd stop > /dev/null 2>&1
cp -r /etc/httpd/* $vst_backups/httpd > /dev/null 2>&1

# Backup PHP-FPM configuration
service php-fpm stop >/dev/null 2>&1
cp /etc/php.ini $vst_backups/php > /dev/null 2>&1
cp -r /etc/php.d  $vst_backups/php > /dev/null 2>&1
cp /etc/php-fpm.conf $vst_backups/php-fpm > /dev/null 2>&1
mv -f /etc/php-fpm.d/* $vst_backups/php-fpm/ > /dev/null 2>&1

# Backup Bind configuration
dnf remove bind-chroot > /dev/null 2>&1
service named stop > /dev/null 2>&1
cp /etc/named.conf $vst_backups/named >/dev/null 2>&1

# Backup Vsftpd configuration
service vsftpd stop > /dev/null 2>&1
cp /etc/vsftpd/vsftpd.conf $vst_backups/vsftpd >/dev/null 2>&1

# Backup ProFTPD configuration
service proftpd stop > /dev/null 2>&1
cp /etc/proftpd.conf $vst_backups/proftpd >/dev/null 2>&1

# Backup Exim configuration
service exim stop > /dev/null 2>&1
cp -r /etc/exim/* $vst_backups/exim >/dev/null 2>&1

# Backup ClamAV configuration
service clamd stop > /dev/null 2>&1
cp /etc/clamd.conf $vst_backups/clamd >/dev/null 2>&1
cp -r /etc/clamd.d $vst_backups/clamd >/dev/null 2>&1

# Backup SpamAssassin configuration
service spamassassin stop > /dev/null 2>&1
cp -r /etc/mail/spamassassin/* $vst_backups/spamassassin >/dev/null 2>&1

# Backup Dovecot configuration
service dovecot stop > /dev/null 2>&1
cp /etc/dovecot.conf $vst_backups/dovecot > /dev/null 2>&1
cp -r /etc/dovecot/* $vst_backups/dovecot > /dev/null 2>&1

# Backup MySQL/MariaDB configuration and data
service mysql stop > /dev/null 2>&1
service mysqld stop > /dev/null 2>&1
service mariadb stop > /dev/null 2>&1
mv /var/lib/mysql $vst_backups/mysql/mysql_datadir >/dev/null 2>&1
cp /etc/my.cnf $vst_backups/mysql > /dev/null 2>&1
cp /etc/my.cnf.d $vst_backups/mysql > /dev/null 2>&1
mv /root/.my.cnf  $vst_backups/mysql > /dev/null 2>&1

# Backup MySQL/MariaDB configuration and data
service postgresql stop > /dev/null 2>&1
mv /var/lib/pgsql/data $vst_backups/postgresql/  >/dev/null 2>&1

# Backup Vesta
service vesta stop > /dev/null 2>&1
mv $VESTA/data/* $vst_backups/vesta > /dev/null 2>&1
mv $VESTA/conf/* $vst_backups/vesta > /dev/null 2>&1


#----------------------------------------------------------#
#                     Package Excludes                     #
#----------------------------------------------------------#

# Excluding packages
if [ "$nginx" = 'no'  ]; then
    software=$(echo "$software" | sed -e "s/^nginx//")
fi
if [ "$apache" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/httpd//")
    software=$(echo "$software" | sed -e "s/mod_ssl//")
    software=$(echo "$software" | sed -e "s/mod_fcgid//")
fi
if [ "$phpfpm" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/php-fpm//")
fi
if [ "$vsftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/vsftpd//")
fi
if [ "$proftpd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/proftpd//")
fi
if [ "$named" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/bind //")
fi
if [ "$exim" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/exim//")
    software=$(echo "$software" | sed -e "s/dovecot//")
    software=$(echo "$software" | sed -e "s/clamd//")
    software=$(echo "$software" | sed -e "s/clamav-server//")
    software=$(echo "$software" | sed -e "s/clamav-update//")
    software=$(echo "$software" | sed -e "s/spamassassin//")
    software=$(echo "$software" | sed -e "s/dovecot//")
    software=$(echo "$software" | sed -e "s/roundcubemail//")
fi
if [ "$clamd" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/clamd//")
    software=$(echo "$software" | sed -e "s/clamav-server//")
    software=$(echo "$software" | sed -e "s/clamav-update//")
fi
if [ "$spamd" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/spamassassin//')
fi
if [ "$dovecot" = 'no' ]; then
    software=$(echo "$software" | sed -e "s/dovecot//")
fi
if [ "$mysql" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/mysql //')
    software=$(echo "$software" | sed -e 's/mysql-server//')
    software=$(echo "$software" | sed -e 's/mariadb //')
    software=$(echo "$software" | sed -e 's/mariadb-server//')
    software=$(echo "$software" | sed -e 's/php-mysql//')
    software=$(echo "$software" | sed -e 's/phpMyAdmin//')
    software=$(echo "$software" | sed -e 's/roundcubemail//')
fi
if [ "$postgresql" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/postgresql //')
    software=$(echo "$software" | sed -e 's/postgresql-server//')
    software=$(echo "$software" | sed -e 's/postgresql-contrib//')
    software=$(echo "$software" | sed -e 's/php-pgsql//')
    software=$(echo "$software" | sed -e 's/phpPgAdmin//')
fi
if [ "$softaculous" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/vesta-softaculous//')
fi
if [ "$iptables" = 'no' ] || [ "$fail2ban" = 'no' ]; then
    software=$(echo "$software" | sed -e 's/fail2ban//')
fi


#----------------------------------------------------------#
#                     Install packages                     #
#----------------------------------------------------------#


# vsftp support
dnf install -y initscripts

# Installing rpm packages

# vi /etc/httpd/conf.modules.d/00-mpm.conf
# comment #LoadModule mpm_event_module modules/mod_mpm_event.so
# uncomment LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
dnf install -y php;
dnf module install -y php:remi-8.2;
dnf module reset -y php:remi-8.2;
dnf module install -y php:remi-8.2;
dnf install -y $software
if [ $? -ne 0 ]; then
    if [ "$remi" = 'yes' ]; then
        dnf -y --skip-broken install $software
    else
        dnf -y --skip-broken install $software
    fi
fi
check_result $? "dnf install failed"


#----------------------------------------------------------#
#                     Configure system                     #
#----------------------------------------------------------#

# Restarting rsyslog
service rsyslog restart > /dev/null 2>&1

# Checking ipv6 on loopback interface
check_lo_ipv6=$(/sbin/ip addr | grep 'inet6')
check_rc_ipv6=$(grep 'scope global dev lo' /etc/rc.local)
if [ ! -z "$check_lo_ipv6)" ] && [ -z "$check_rc_ipv6" ]; then
    ip addr add ::2/128 scope global dev lo
    echo "# Vesta: Workraround for openssl validation func" >> /etc/rc.local
    echo "ip addr add ::2/128 scope global dev lo" >> /etc/rc.local
    chmod a+x /etc/rc.local
fi

# Disabling SELinux
if [ -e '/etc/sysconfig/selinux' ]; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0 2>/dev/null
fi

# Disabling iptables
service iptables stop
service firewalld stop >/dev/null 2>&1

# Disabling webalizer routine
rm -f /etc/cron.daily/00webalizer

# Adding backup user
adduser backup 2>/dev/null
ln -sf /home/backup /backup
chmod a+x /backup

# Set directory color
echo 'LS_COLORS="$LS_COLORS:di=00;33"' >> /etc/profile

# Register /sbin/nologin and /usr/sbin/nologin
echo "/sbin/nologin" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells

# Changing default systemd interval
if [ "$release" -eq '7' ]; then
    # Hi Lennart
    echo "DefaultStartLimitInterval=1s" >> /etc/systemd/system.conf
    echo "DefaultStartLimitBurst=60" >> /etc/systemd/system.conf
    systemctl daemon-reexec
fi


#----------------------------------------------------------#
#                     Configure VESTA                      #
#----------------------------------------------------------#

# Installing sudo configuration
mkdir -p /etc/sudoers.d
cp -f $vestacp/sudo/admin /etc/sudoers.d/
chmod 440 /etc/sudoers.d/admin

# Configuring system env
echo "export VESTA='$VESTA'" > /etc/profile.d/vesta.sh
chmod 755 /etc/profile.d/vesta.sh
source /etc/profile.d/vesta.sh
echo 'PATH=$PATH:'$VESTA'/bin' >> /root/.bash_profile
echo 'export PATH' >> /root/.bash_profile
source /root/.bash_profile

# Configuring logrotate for vesta logs
cp -f $vestacp/logrotate/vesta /etc/logrotate.d/

# Building directory tree and creating some blank files for Vesta
mkdir -p $VESTA/conf $VESTA/log $VESTA/ssl $VESTA/data/ips \
    $VESTA/data/queue $VESTA/data/users $VESTA/data/firewall \
    $VESTA/data/sessions
touch $VESTA/data/queue/backup.pipe $VESTA/data/queue/disk.pipe \
    $VESTA/data/queue/webstats.pipe $VESTA/data/queue/restart.pipe \
    $VESTA/data/queue/traffic.pipe $VESTA/log/system.log \
    $VESTA/log/nginx-error.log $VESTA/log/auth.log
chmod 750 $VESTA/conf $VESTA/data/users $VESTA/data/ips $VESTA/log
chmod -R 750 $VESTA/data/queue
chmod 660 $VESTA/log/*
rm -f /var/log/vesta
ln -s $VESTA/log /var/log/vesta
chmod 770 $VESTA/data/sessions

# Generating Vesta configuration
rm -f $VESTA/conf/vesta.conf 2>/dev/null
touch $VESTA/conf/vesta.conf
chmod 660 $VESTA/conf/vesta.conf

# Web stack
if [ "$apache" = 'yes' ] && [ "$nginx" = 'no' ] ; then
    echo "WEB_SYSTEM='httpd'" >> $VESTA/conf/vesta.conf
    echo "WEB_RGROUPS='apache'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='mod_ssl'"  >> $VESTA/conf/vesta.conf
    echo "STATS_SYSTEM=''" >> $VESTA/conf/vesta.conf
fi
if [ "$apache" = 'yes' ] && [ "$nginx"  = 'yes' ] ; then
    echo "WEB_SYSTEM='httpd'" >> $VESTA/conf/vesta.conf
    echo "WEB_RGROUPS='apache'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='8080'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='8443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='mod_ssl'"  >> $VESTA/conf/vesta.conf
    echo "PROXY_SYSTEM='nginx'" >> $VESTA/conf/vesta.conf
    echo "PROXY_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "PROXY_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "STATS_SYSTEM=''" >> $VESTA/conf/vesta.conf
fi
if [ "$apache" = 'no' ] && [ "$nginx"  = 'yes' ]; then
    echo "WEB_SYSTEM='nginx'" >> $VESTA/conf/vesta.conf
    echo "WEB_PORT='80'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL_PORT='443'" >> $VESTA/conf/vesta.conf
    echo "WEB_SSL='openssl'"  >> $VESTA/conf/vesta.conf
    if [ "$phpfpm" = 'yes' ]; then
        echo "WEB_BACKEND='php-fpm'" >> $VESTA/conf/vesta.conf
    fi
    echo "STATS_SYSTEM=''" >> $VESTA/conf/vesta.conf
fi

# FTP stack
if [ "$vsftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='vsftpd'" >> $VESTA/conf/vesta.conf
fi
if [ "$proftpd" = 'yes' ]; then
    echo "FTP_SYSTEM='proftpd'" >> $VESTA/conf/vesta.conf
fi

# DNS stack
if [ "$named" = 'yes' ]; then
    echo "DNS_SYSTEM='named'" >> $VESTA/conf/vesta.conf
fi

# Mail stack
if [ "$exim" = 'yes' ]; then
    echo "MAIL_SYSTEM='exim'" >> $VESTA/conf/vesta.conf
    if [ "$clamd" = 'yes'  ]; then
        echo "ANTIVIRUS_SYSTEM='clamav'" >> $VESTA/conf/vesta.conf
    fi
    if [ "$spamd" = 'yes' ]; then
        echo "ANTISPAM_SYSTEM='spamassassin'" >> $VESTA/conf/vesta.conf
    fi
    if [ "$dovecot" = 'yes' ]; then
        echo "IMAP_SYSTEM='dovecot'" >> $VESTA/conf/vesta.conf
    fi
fi

# Cron daemon
echo "CRON_SYSTEM='crond'" >> $VESTA/conf/vesta.conf

# Firewall stack
if [ "$iptables" = 'yes' ]; then
    echo "FIREWALL_SYSTEM='iptables'" >> $VESTA/conf/vesta.conf
fi
if [ "$iptables" = 'yes' ] && [ "$fail2ban" = 'yes' ]; then
    echo "FIREWALL_EXTENSION='fail2ban'" >> $VESTA/conf/vesta.conf
fi

# Disk quota
if [ "$quota" = 'yes' ]; then
    echo "DISK_QUOTA='yes'" >> $VESTA/conf/vesta.conf
fi

# Backups
echo "BACKUP_SYSTEM='local'" >> $VESTA/conf/vesta.conf

# Language
echo "LANGUAGE='$lang'" >> $VESTA/conf/vesta.conf

# Version
echo "VERSION='0.9.8'" >> $VESTA/conf/vesta.conf

# Installing hosting packages
cp -rf $vestacp/packages $VESTA/data/

# Installing templates
cp -rf $vestacp/templates $VESTA/data/

# Copying index.html to default documentroot
cp $VESTA/data/templates/web/skel/public_html/index.html /var/www/html/
sed -i 's/%domain%/It worked!/g' /var/www/html/index.html

# Installing firewall rules
cp -rf $vestacp/firewall $VESTA/data/

# Configuring server hostname
$VESTA/bin/v-change-sys-hostname $servername 2>/dev/null

# Generating SSL certificate
$VESTA/bin/v-generate-ssl-cert $(hostname) $email 'US' 'California' \
     'San Francisco' 'Vesta Control Panel' 'IT' > /tmp/vst.pem

# Parsing certificate file
crt_end=$(grep -n "END CERTIFICATE-" /tmp/vst.pem |cut -f 1 -d:)
key_start=$(grep -n "BEGIN RSA" /tmp/vst.pem |cut -f 1 -d:)
key_end=$(grep -n  "END RSA" /tmp/vst.pem |cut -f 1 -d:)

# Adding SSL certificate
cd $VESTA/ssl
sed -n "1,${crt_end}p" /tmp/vst.pem > certificate.crt
sed -n "$key_start,${key_end}p" /tmp/vst.pem > certificate.key
chown root:mail $VESTA/ssl/*
chmod 660 $VESTA/ssl/*
rm /tmp/vst.pem


#----------------------------------------------------------#
#                     Configure Nginx                      #
#----------------------------------------------------------#

if [ "$nginx" = 'yes' ]; then
    rm -f /etc/nginx/conf.d/*.conf
    cp -f $vestacp/nginx/nginx.conf /etc/nginx/
    cp -f $vestacp/nginx/status.conf /etc/nginx/conf.d/
    cp -f $vestacp/nginx/phpmyadmin.inc /etc/nginx/conf.d/
    cp -f $vestacp/nginx/phppgadmin.inc /etc/nginx/conf.d/
    cp -f $vestacp/nginx/webmail.inc /etc/nginx/conf.d/
    cp -f $vestacp/logrotate/nginx /etc/logrotate.d/
    echo > /etc/nginx/conf.d/vesta.conf
    mkdir -p /var/log/nginx/domains
    if [ "$release" -ge 7 ]; then
        mkdir -p /etc/systemd/system/nginx.service.d
        cd /etc/systemd/system/nginx.service.d
        echo "[Service]" > limits.conf
        echo "LimitNOFILE=500000" >> limits.conf
    fi
    chkconfig nginx on
    service nginx start
    check_result $? "nginx start failed"

    # Workaround for OpenVZ/Virtuozzo
    if [ "$release" -ge '7' ] && [ -e "/proc/vz/veinfo" ]; then
        echo "#Vesta: workraround for networkmanager" >> /etc/rc.local
        echo "sleep 3 && service nginx restart" >> /etc/rc.local
    fi
fi


#----------------------------------------------------------#
#                    Configure Apache                      #
#----------------------------------------------------------#

if [ "$apache" = 'yes'  ]; then
    cp -f $vestacp/httpd/httpd.conf /etc/httpd/conf/
    cp -f $vestacp/httpd/status.conf /etc/httpd/conf.d/
    cp -f $vestacp/httpd/ssl.conf /etc/httpd/conf.d/
    cp -f $vestacp/logrotate/httpd /etc/logrotate.d/
    if [ $release -lt 7 ]; then
        cd /etc/httpd/conf.d
        echo "MEFaccept 127.0.0.1" >> mod_extract_forwarded.conf
        echo > proxy_ajp.conf
    fi
    if [ -e "/etc/httpd/conf.modules.d/00-dav.conf" ]; then
        cd /etc/httpd/conf.modules.d
        sed -i "s/^/#/" 00-dav.conf 00-lua.conf 00-proxy.conf
    fi
    echo > /etc/httpd/conf.d/vesta.conf
    cd /var/log/httpd
    touch access_log error_log suexec.log
    chmod 640 access_log error_log suexec.log
    chmod -f 777 /var/lib/php/session
    chmod a+x /var/log/httpd
    mkdir -p /var/log/httpd/domains
    chmod 751 /var/log/httpd/domains
    if [ "$release" -ge 7 ]; then
        mkdir -p /etc/systemd/system/httpd.service.d
        cd /etc/systemd/system/httpd.service.d
        echo "[Service]" > limits.conf
        echo "LimitNOFILE=500000" >> limits.conf
    fi
    chkconfig httpd on
    rm -fv /etc/httpd/conf.modules.d/10-proxy_h2.conf;
    rm -fv /etc/httpd/conf.d/ruid2.conf;
    wget https://raw.githubusercontent.com/patombugua/vesta8/master/15-php.conf -O /etc/httpd/conf.modules.d/15-php.conf;
    service httpd start
    check_result $? "httpd start failed"

    # Workaround for OpenVZ/Virtuozzo
    if [ "$release" -ge '7' ] && [ -e "/proc/vz/veinfo" ]; then
        echo "#Vesta: workraround for networkmanager" >> /etc/rc.local
        echo "sleep 2 && service httpd restart" >> /etc/rc.local
    fi
fi


#----------------------------------------------------------#
#                     Configure PHP-FPM                    #
#----------------------------------------------------------#

if [ "$phpfpm" = 'yes' ]; then
    cp -f $vestacp/php-fpm/www.conf /etc/php-fpm.d/
    chkconfig php-fpm on
    service php-fpm start
    check_result $? "php-fpm start failed"
fi


#----------------------------------------------------------#
#                     Configure PHP                        #
#----------------------------------------------------------#

ZONE=$(timedatectl 2>/dev/null|grep Timezone|awk '{print $2}')
if [ -e '/etc/sysconfig/clock' ]; then
    source /etc/sysconfig/clock
fi
if [ -z "$ZONE" ]; then
    ZONE='UTC'
fi
for pconf in $(find /etc/php* -name php.ini); do
    sed -i "s|;date.timezone =|date.timezone = $ZONE|g" $pconf
    sed -i 's%_open_tag = Off%_open_tag = On%g' $pconf
done


#----------------------------------------------------------#
#                    Configure Vsftpd                      #
#----------------------------------------------------------#

if [ "$vsftpd" = 'yes' ]; then
    cp -f $vestacp/vsftpd/vsftpd.conf /etc/vsftpd/
    # bash centos8.sh --nginx yes --apache yes --phpfpm no --named yes --remi yes --vsftpd yes --proftpd no --iptables yes --fail2ban yes --quota yes --exim yes --dovecot yes --spamassassin yes --clamav no --softaculous no --mysql yes --postgresql no --force;
    chkconfig vsftpd on
    service vsftpd start
    check_result $? "vsftpd start failed"
fi


#----------------------------------------------------------#
#                    Configure ProFTPD                     #
#----------------------------------------------------------#

if [ "$proftpd" = 'yes' ]; then
    cp -f $vestacp/proftpd/proftpd.conf /etc/
    chkconfig proftpd on
    service proftpd start
    check_result $? "proftpd start failed"
fi


#----------------------------------------------------------#
#                  Configure MySQL/MariaDB                 #
#----------------------------------------------------------#

if [ "$mysql" = 'yes' ]; then

    mycnf="my-small.cnf"
    if [ $memory -gt 1200000 ]; then
        mycnf="my-medium.cnf"
    fi
    if [ $memory -gt 3900000 ]; then
        mycnf="my-large.cnf"
    fi

    mkdir -p /var/lib/mysql
    chown mysql:mysql /var/lib/mysql
    mkdir -p /etc/my.cnf.d

    if [ $release -lt 7 ]; then
        service='mysqld'
    else
        service='mariadb'
    fi

    cp -f $vestacp/$service/$mycnf /etc/my.cnf
    chkconfig $service on
    service $service start
    if [ "$?" -ne 0 ]; then
        if [ -e "/proc/user_beancounters" ]; then
            # Fix for aio on OpenVZ
            sed -i "s/#innodb_use_native/innodb_use_native/g" /etc/my.cnf
        fi
        service $service start
        check_result $? "$service start failed"
    fi

    # Securing MySQL installation
    mpass=$(gen_pass)
    mysqladmin -u root password $mpass
    echo -e "[client]\npassword='$mpass'\n" > /root/.my.cnf
    chmod 600 /root/.my.cnf
    mysql -e "DELETE FROM mysql.user WHERE User=''"
    mysql -e "DROP DATABASE test" >/dev/null 2>&1
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
    mysql -e "DELETE FROM mysql.user WHERE user='' or password='';"
    mysql -e "FLUSH PRIVILEGES"

    # Configuring phpMyAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $vestacp/pma/phpMyAdmin.conf /etc/httpd/conf.d/
    fi
    mysql < /usr/share/phpMyAdmin/sql/create_tables.sql
    p=$(gen_pass)
    mysql -e "GRANT ALL ON phpmyadmin.*
        TO phpmyadmin@localhost IDENTIFIED BY '$p'"
    cp -f $vestacp/pma/config.inc.conf /etc/phpMyAdmin/config.inc.php
    sed -i "s/%blowfish_secret%/$(gen_pass 32)/g" /etc/phpMyAdmin/config.inc.php
    sed -i "s/%phpmyadmin_pass%/$p/g" /etc/phpMyAdmin/config.inc.php
    chmod 777 /var/lib/phpMyAdmin/temp
    chmod 777 /var/lib/phpMyAdmin/save
fi


# In /usr/local/vesta/conf/vesta.conf change
# from DB_SYSTEM='mysql' to DB_SYSTEM='mariadb'


#----------------------------------------------------------#
#                   Configure PostgreSQL                   #
#----------------------------------------------------------#

if [ "$postgresql" = 'yes' ]; then
    ppass=$(gen_pass)
    if [ $release -eq 5 ]; then
        service postgresql start
        sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'"
        service postgresql stop
        cp -f $vestacp/postgresql/pg_hba.conf /var/lib/pgsql/data/
        service postgresql start
    else
        service postgresql initdb
        cp -f $vestacp/postgresql/pg_hba.conf /var/lib/pgsql/data/
        service postgresql start
        sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$ppass'"
    fi
    # Configuring phpPgAdmin
    if [ "$apache" = 'yes' ]; then
        cp -f $vestacp/pga/phpPgAdmin.conf /etc/httpd/conf.d/
    fi
    cp -f $vestacp/pga/config.inc.php /etc/phpPgAdmin/
fi


#----------------------------------------------------------#
#                      Configure Bind                      #
#----------------------------------------------------------#

if [ "$named" = 'yes' ]; then
    cp -f $vestacp/named/named.conf /etc/
    chown root:named /etc/named.conf
    chmod 640 /etc/named.conf
    chkconfig named on
    service named start
    check_result $? "named start failed"
fi


#----------------------------------------------------------#
#                      Configure Exim                      #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ]; then
    gpasswd -a exim mail
    cp -f $vestacp/exim/exim.conf /etc/exim/
    cp -f $vestacp/exim/dnsbl.conf /etc/exim/
    cp -f $vestacp/exim/spam-blocks.conf /etc/exim/
    touch /etc/exim/white-blocks.conf

    if [ "$spamd" = 'yes' ]; then
        sed -i "s/#SPAM/SPAM/g" /etc/exim/exim.conf
    fi
    if [ "$clamd" = 'yes' ]; then
        sed -i "s/#CLAMD/CLAMD/g" /etc/exim/exim.conf
    fi

    chmod 640 /etc/exim/exim.conf
    rm -rf /etc/exim/domains
    mkdir -p /etc/exim/domains

    rm -f /etc/alternatives/mta
    ln -s /usr/sbin/sendmail.exim /etc/alternatives/mta
    chkconfig sendmail off 2>/dev/null
    service sendmail stop 2>/dev/null
    chkconfig postfix off 2>/dev/null
    service postfix stop 2>/dev/null

    chkconfig exim on
    service exim start
    check_result $? "exim start failed"
fi


#----------------------------------------------------------#
#                     Configure Dovecot                    #
#----------------------------------------------------------#

if [ "$dovecot" = 'yes' ]; then
    gpasswd -a dovecot mail
    cp -rf $vestacp/dovecot /etc/
    cp -f $vestacp/logrotate/dovecot /etc/logrotate.d/
    chown -R root:root /etc/dovecot*
    if [ "$release" -eq 7 ]; then
        sed -i "s#namespace inbox {#namespace inbox {\n  inbox = yes#" /etc/dovecot/conf.d/15-mailboxes.conf
    fi
    chkconfig dovecot on
    service dovecot start
    check_result $? "dovecot start failed"
fi


#----------------------------------------------------------#
#                     Configure ClamAV                     #
#----------------------------------------------------------#

if [ "$clamd" = 'yes' ]; then
    useradd clam -s /sbin/nologin -d /var/lib/clamav 2>/dev/null
    gpasswd -a clam exim
    gpasswd -a clam mail
    cp -f $vestacp/clamav/clamd.conf /etc/
    cp -f $vestacp/clamav/freshclam.conf /etc/
    mkdir -p /var/log/clamav /var/run/clamav
    chown clam:clam /var/log/clamav /var/run/clamav
    chown -R clam:clam /var/lib/clamav
    if [ "$release" -ge '7' ]; then
        cp -f $vestacp/clamav/clamd.service /usr/lib/systemd/system/
        systemctl --system daemon-reload
    fi
    /usr/bin/freshclam
    if [ "$release" -ge '7' ]; then
        sed -i "s/nofork/foreground/" /usr/lib/systemd/system/clamd.service
        systemctl daemon-reload
    fi
    chkconfig clamd on
    service clamd start
    #check_result $? "clamd start failed"
fi


#----------------------------------------------------------#
#                  Configure SpamAssassin                  #
#----------------------------------------------------------#

if [ "$spamd" = 'yes' ]; then
    chkconfig spamassassin on
    service spamassassin start
    check_result $? "spamassassin start failed"
    if [ "$release" -ge '7' ]; then
        groupadd -g 1001 spamd
        useradd -u 1001 -g spamd -s /sbin/nologin -d \
            /var/lib/spamassassin spamd
        mkdir /var/lib/spamassassin
        chown spamd:spamd /var/lib/spamassassin
    fi
fi


#----------------------------------------------------------#
#                   Configure RoundCube                    #
#----------------------------------------------------------#

if [ "$exim" = 'yes' ] && [ "$mysql" = 'yes' ]; then
    if [ "$apache" = 'yes' ]; then
        cp -f $vestacp/roundcube/roundcubemail.conf /etc/httpd/conf.d/
    fi
    cp -f $vestacp/roundcube/main.inc.php /etc/roundcubemail/config.inc.php
    cd /usr/share/roundcubemail/plugins/password
    cp -f $vestacp/roundcube/vesta.php drivers/vesta.php
    cp -f $vestacp/roundcube/config.inc.php config.inc.php
    sed -i "s/localhost/$servername/g" config.inc.php
    chmod a+r /etc/roundcubemail/*
    chmod -f 777 /var/log/roundcubemail
    r="$(gen_pass)"
    mysql -e "CREATE DATABASE roundcube"
    mysql -e "GRANT ALL ON roundcube.* TO
            roundcube@localhost IDENTIFIED BY '$r'"
    sed -i "s/%password%/$r/g" /etc/roundcubemail/config.inc.php
    chmod 640 /etc/roundcubemail/config.inc.php
    chown root:apache /etc/roundcubemail/config.inc.php
    if [ -e "/usr/share/roundcubemail/SQL/mysql.initial.sql" ]; then
        mysql roundcube < /usr/share/roundcubemail/SQL/mysql.initial.sql
    else
        mysql roundcube < /usr/share/doc/roundcubemail-*/SQL/mysql.initial.sql
    fi
fi


#----------------------------------------------------------#
#                    Configure Fail2Ban                    #
#----------------------------------------------------------#

if [ "$fail2ban" = 'yes' ]; then
    cp -rf $vestacp/fail2ban /etc/
    if [ "$dovecot" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n dovecot-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$exim" = 'no' ]; then
        fline=$(cat /etc/fail2ban/jail.local |grep -n exim-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/true/false/" /etc/fail2ban/jail.local
    fi
    if [ "$vsftpd" = 'yes' ]; then
        #Create vsftpd Log File
        if [ ! -f "/var/log/vsftpd.log" ]; then
            touch /var/log/vsftpd.log
        fi
        fline=$(cat /etc/fail2ban/jail.local |grep -n vsftpd-iptables -A 2)
        fline=$(echo "$fline" |grep enabled |tail -n1 |cut -f 1 -d -)
        sed -i "${fline}s/false/true/" /etc/fail2ban/jail.local
    fi
    chkconfig fail2ban on
    mkdir -p /var/run/fail2ban
    if [ -e "/usr/lib/systemd/system/fail2ban.service" ]; then
        exec_pre='ExecStartPre=/bin/mkdir -p /var/run/fail2ban'
        sed -i "s|\[Service\]|[Service]\n$exec_pre|g" \
            /usr/lib/systemd/system/fail2ban.service
        systemctl daemon-reload
    fi
    service fail2ban start
    check_result $? "fail2ban start failed"
fi


#----------------------------------------------------------#
#                   Configure Admin User                   #
#----------------------------------------------------------#

# Deleting old admin user
if [ ! -z "$(grep ^admin: /etc/passwd)" ] && [ "$force" = 'yes' ]; then
    chattr -i /home/admin/conf > /dev/null 2>&1
    userdel -f admin >/dev/null 2>&1
    chattr -i /home/admin/conf >/dev/null 2>&1
    mv -f /home/admin  $vst_backups/home/ >/dev/null 2>&1
    rm -f /tmp/sess_* >/dev/null 2>&1
fi
if [ ! -z "$(grep ^admin: /etc/group)" ] && [ "$force" = 'yes' ]; then
    groupdel admin > /dev/null 2>&1
fi

# Adding Vesta admin account
$VESTA/bin/v-add-user admin $vpass $email default System Administrator
check_result $? "can't create admin user"
$VESTA/bin/v-change-user-shell admin bash
$VESTA/bin/v-change-user-language admin $lang

# Configuring system IPs
$VESTA/bin/v-update-sys-ip

# Get main IP
ip=$(ip addr|grep 'inet '|grep global|head -n1|awk '{print $2}'|cut -f1 -d/)

# Configuring firewall
if [ "$iptables" = 'yes' ]; then
    chkconfig firewalld off >/dev/null 2>&1
    $VESTA/bin/v-update-firewall
fi

# Get public IP
pub_ip=$(curl -s -4 git.sysdop.com/ip.php)
if [ ! -z "$pub_ip" ] && [ "$pub_ip" != "$ip" ]; then
    echo "$VESTA/bin/v-update-sys-ip" >> /etc/rc.local
    $VESTA/bin/v-change-sys-ip-nat $ip $pub_ip
    ip=$pub_ip
fi

# Configuring MySQL/MariaDB host
if [ "$mysql" = 'yes' ]; then
    $VESTA/bin/v-add-database-host mysql localhost root $mpass
    $VESTA/bin/v-add-database admin default default $(gen_pass) mysql
fi

# Configuring PostgreSQL host
if [ "$postgresql" = 'yes' ]; then
    $VESTA/bin/v-add-database-host pgsql localhost postgres $ppass
    $VESTA/bin/v-add-database admin db db $(gen_pass) pgsql
fi

# Adding default domain
$VESTA/bin/v-add-domain admin $servername

# Adding cron jobs
command="sudo $VESTA/bin/v-update-sys-queue disk"
$VESTA/bin/v-add-cron-job 'admin' '15' '02' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue traffic"
$VESTA/bin/v-add-cron-job 'admin' '10' '00' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue webstats"
$VESTA/bin/v-add-cron-job 'admin' '30' '03' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-queue backup"
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-backup-users"
$VESTA/bin/v-add-cron-job 'admin' '10' '05' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-user-stats"
$VESTA/bin/v-add-cron-job 'admin' '20' '00' '*' '*' '*' "$command"
command="sudo $VESTA/bin/v-update-sys-rrd"
$VESTA/bin/v-add-cron-job 'admin' '*/5' '*' '*' '*' '*' "$command"

# Enabling file system quota
if [ "$quota" = 'yes' ]; then
    $VESTA/bin/v-add-sys-quota
fi

# Enabling Softaculous plugin
if [ "$softaculous" = 'yes' ]; then
    $VESTA/bin/v-add-vesta-softaculous
fi

# Starting Vesta service
chkconfig vesta on
service vesta start
check_result $? "vesta start failed"
chown admin:admin $VESTA/data/sessions

# Adding notifications
$VESTA/upd/add_notifications.sh

# Adding cronjob for auto updates
$VESTA/bin/v-add-cron-vesta-autoupdate


#----------------------------------------------------------#
#                   Vesta Access Info                      #
#----------------------------------------------------------#

# Comparing hostname and IP
host_ip=$(host $servername |head -n 1 |awk '{print $NF}')
if [ "$host_ip" = "$ip" ]; then
    ip="$servername"
fi

# Sending notification to admin email
echo -e "Congratulations, you have just successfully installed \
Vesta Control Panel by Carlos Frias

    https://SERVERIP:8083
    username: admin
    password: $vpass

We hope that you enjoy your installation of Vesta. Please \
feel free to contact us anytime if you have any questions.
Thank you.

--
Sincerely yours
Sysdop.com
" > $tmpfile

send_mail="$VESTA/web/inc/mail-wrapper.php"
cat $tmpfile | $send_mail -s "Vesta Control Panel" $email

# Congrats
echo '======================================================='
echo
echo ' _|      _|  _|_|_|_|    _|_|_|  _|_|_|_|_|    _|_|   '
echo ' _|      _|  _|        _|            _|      _|    _| '
echo ' _|      _|  _|_|_|      _|_|        _|      _|_|_|_| '
echo '   _|  _|    _|              _|      _|      _|    _| '
echo '     _|      _|_|_|_|  _|_|_|        _|      _|    _| '
echo
echo
cat $tmpfile
rm -f $tmpfile
dnf install -y --skip-broken gmp-devel; v-delete-vesta-softaculous; rm -fv /usr/local/vesta/softaculous/vst_installed; dnf remove -y vesta-softaculous; rm -rfv /usr/local/vesta/softaculous; rm -rfv /var/softaculous; rm -fv /etc/httpd/conf.d/ruid2.conf;
rm -fv /usr/lib/systemd/system/httpd.service.d/*; systemctl daemon-reload;
# EOF



#sudo chmod o+w ./public_html/ -R
