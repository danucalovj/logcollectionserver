#!/bin/bash

# Client IP Configuration
export CLIENT_SERVER_IP=1.2.3.4

# Apt-Get Update Everything
sudo apt-get update

# Configure UFW
sudo apt-get -y install ufw
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow proto tcp from $CLIENT_SERVER_IP to any port 514
sudo ufw allow proto udp from $CLIENT_SERVER_IP to any port 514
sudo ufw enable

# Rsyslog Configuration
# UDP 514 Input
echo "module(load=\"imudp\")" >> /etc/rsyslog.d/99-home.conf                                                                             
echo "input(type=\"imudp\" port=\"514\")" >> /etc/rsyslog.d/99-home.conf
# TCP 514 Input
echo "module(load=\"imtcp\")" >> /etc/rsyslog.d/99-home.conf                                                             
echo "input(type=\"imtcp\" port=\"514\")" >> /etc/rsyslog.d/99-home.conf
# Allowed Sender (Client IP)
echo -n "\$AllowedSender TCP, " >> AllowedSender.txt
echo "$CLIENT_SERVER_IP" >> AllowedSender.txt
echo -n "\$AllowedSender UDP, " >> AllowedSender.txt
echo "$CLIENT_SERVER_IP" >> AllowedSender.txt
cat AllowedSender.txt >> /etc/rsyslog.d/99-home.conf
rm AllowedSender.txt

# Rsyslog Restart
sudo service rsyslog restart
