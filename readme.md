Steps to Install Vesta Control Panel (VestaCP) in CentOS 8 x64 System

1) SSH

Enter in Console/Terminal with root (sudo su root) or su root

2) RUN

dnf install -y wget perl psmisc epel-release; dnf install -y dos2unix;

3) INSTALL

cd; wget https://raw.githubusercontent.com/patombugua/vesta8/master/install.sh -O /root/install.sh; dos2unix install.sh; sed -i 's/\r$//' install.sh; sh install.sh;


When installing, the installation will fail a few time
1, Run the command again.
2, If httpd fails to start
    

And done :)

For troubleshooting, contact me by email.:

