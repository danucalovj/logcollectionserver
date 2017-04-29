#!/bin/bash

# Client IP Configuration
export CLIENT_SERVER_IP=1.2.3.4

# Install + Configure Extras
sudo apt-get update
sudo apt-get -y install jruby
sudo apt-get -y install ruby
sudo apt-get -y install ruby-bundler
sudo gem install bundler
sudo apt-get -y install python
curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
sudo apt-get -y install nodejs
sudo apt-get -y install build-essential
sudo apt-get -y install ufw

# Configure UFW
sudo ufw default allow outgoing
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow proto tcp from $CLIENT_SERVER_IP to any port 514
sudo ufw allow proto udp from $CLIENT_SERVER_IP to any port 514
sudo ufw enable

# Add GPG Keys
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# Enable APT SSL Support
sudo apt-get -y install apt-transport-https

# Updates Repository Sources
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list
sudo add-apt-repository -y ppa:webupd8team/java

# Apt-Get Update Everything
sudo apt-get update

# Install Kibana
sudo apt-get -y install kibana
sed -i 's@#server.host: "localhost"@server.host: "localhost"@g' /etc/kibana/kibana.yml
sudo update-rc.d kibana defaults 96 9
sudo service kibana start

# Install NGINX
sudo apt-get -y install nginx apache2-utils
sudo htpasswd -cb /etc/nginx/htpasswd.users kibanaadmin UseASecurePassword
echo "" > /etc/nginx/sites-available/default
echo "server {" >> /etc/nginx/sites-available/default
echo "    listen 80;" >> /etc/nginx/sites-available/default
echo "    auth_basic \"Restricted Access\";" >> /etc/nginx/sites-available/default
echo "    auth_basic_user_file /etc/nginx/htpasswd.users;" >> /etc/nginx/sites-available/default
echo "    location / {" >> /etc/nginx/sites-available/default
echo "        proxy_pass http://localhost:5601;" >> /etc/nginx/sites-available/default
echo "        proxy_http_version 1.1;" >> /etc/nginx/sites-available/default
echo "        proxy_set_header Upgrade \$http_upgrade;" >> /etc/nginx/sites-available/default
echo "        proxy_set_header Connection 'upgrade';" >> /etc/nginx/sites-available/default
echo "        proxy_set_header Host \$host;" >> /etc/nginx/sites-available/default
echo "        proxy_cache_bypass \$http_upgrade;" >> /etc/nginx/sites-available/default        
echo "    }" >> /etc/nginx/sites-available/default
echo "}" >> /etc/nginx/sites-available/default
sudo service nginx restart

# Install Java
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
sudo apt-get -y install oracle-java8-installer

# Install ElasticSearch
sudo apt-get -y install elasticsearch
echo "network.host: localhost" >> /etc/elasticsearch/elasticsearch.yml
sudo service elasticsearch restart
sudo update-rc.d elasticsearch defaults 95 10

# Install Logstash
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list
sudo apt-get update
sudo apt-get -y install logstash
sudo mkdir -p /etc/pki/tls/certs
sudo mkdir /etc/pki/tls/private
sed -i 's/subjectAltName/#subjectAltName/g' /etc/ssl/openssl.cnf
echo -n "subjectAltName = IP: " >> subjectAltName.txt
/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}' >> subjectAltName.txt
cat subjectAltName.txt >> /etc/ssl/openssl.cnf
rm subjectAltName.txt

# Logstash SSL Keys
sudo openssl req -config /etc/ssl/openssl.cnf -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout /etc/pki/tls/private/logstash-forwarder.key -out /etc/pki/tls/certs/logstash-forwarder.crt

# Install Logstash - Continued
# 02-beats-input.conf
echo "input {" > /etc/logstash/conf.d/02-beats-input.conf
echo "  beats {" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    port => 5044" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    ssl => true" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    ssl_certificate => \"/etc/pki/tls/certs/logstash-forwarder.crt"\" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    ssl_key => \"/etc/pki/tls/private/logstash-forwarder.key"\" >> /etc/logstash/conf.d/02-beats-input.conf
echo "  }" >> /etc/logstash/conf.d/02-beats-input.conf
echo "}" >> /etc/logstash/conf.d/02-beats-input.conf
# 10-syslog-filter.conf
echo "filter {" > /etc/logstash/conf.d/10-syslog-filter.conf
echo "  if [type] == \"syslog\" {" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "    grok {" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "      match => { \"message\" => \"%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}\" }" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "      add_field => [ \"received_at\", \"%{@timestamp}\" ]" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "      add_field => [ \"received_from\", \"%{host}\" ]" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "    }" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "    syslog_pri { }" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "    date {" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "      match => [ \"syslog_timestamp\", \"MMM  d HH:mm:ss\", \"MMM dd HH:mm:ss\" ]" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "    }" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "  }" >> /etc/logstash/conf.d/10-syslog-filter.conf
echo "}" >> /etc/logstash/conf.d/10-syslog-filter.conf
# 30-elasticsearch-output.conf
echo "output {" > /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "  elasticsearch {" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    hosts => [\"localhost:9200\"]" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    sniffing => true" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    manage_template => false" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    index => \"%{[@metadata][beat]}-%{+YYYY.MM.dd}\"" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    document_type => \"%{[@metadata][type]}\"" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "  }" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "}" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
# Logtash Service Restart
sudo service logstash configtest
sudo service logstash restart
sudo update-rc.d logstash defaults 96 9

# Install Filebeat
sudo apt-get -y install filebeat
# filebeat.yml
echo "filebeat:" > /etc/filebeat/filebeat.yml        
echo "  prospectors:" >> /etc/filebeat/filebeat.yml
echo "    -" >> /etc/filebeat/filebeat.yml  
echo "      paths:" >> /etc/filebeat/filebeat.yml  
echo "        - /var/log/syslog" >> /etc/filebeat/filebeat.yml  
echo "      input_type: log" >> /etc/filebeat/filebeat.yml  
echo "      document_type: syslog" >> /etc/filebeat/filebeat.yml  
echo "  registry_file: /var/lib/filebeat/registry" >> /etc/filebeat/filebeat.yml  
echo "output:" >> /etc/filebeat/filebeat.yml  
echo "  elasticsearch:" >> /etc/filebeat/filebeat.yml  
echo "    hosts: [\"localhost:9200\"]" >> /etc/filebeat/filebeat.yml  
echo "    bulk_max_size: 1024" >> /etc/filebeat/filebeat.yml  
echo "    tls:" >> /etc/filebeat/filebeat.yml  
echo "      certificate_authorities: [\"/etc/pki/tls/certs/logstash-forwarder.crt\"]" >> /etc/filebeat/filebeat.yml  
echo "shipper:" >> /etc/filebeat/filebeat.yml  
echo "logging:" >> /etc/filebeat/filebeat.yml  
echo "  files:" >> /etc/filebeat/filebeat.yml  
echo "    rotateeverybytes: 10485760 # = 10MB" >> /etc/filebeat/filebeat.yml
# Filebeat Template
curl -O https://raw.githubusercontent.com/danucalovj/logcollectionserver/master/filebeat-index-template.json
curl -XPUT 'http://localhost:9200/_template/filebeat?pretty' -d@filebeat-index-template.json
# Filebeat Service Restart
sudo service filebeat restart
sudo update-rc.d filebeat defaults 95 10

# Rsyslog Configuration
# UDP 514 Input
echo "module(load=\"imudp\")" >> /etc/rsyslog.d/99-logstashelastic.conf                                                                             
echo "input(type=\"imudp\" port=\"514\")" >> /etc/rsyslog.d/99-logstashelastic.conf
# TCP 514 Input
echo "module(load=\"imtcp\")" >> /etc/rsyslog.d/99-logstashelastic.conf                                                             
echo "input(type=\"imtcp\" port=\"514\")" >> /etc/rsyslog.d/99-logstashelastic.conf
# Allowed Sender (Client IP)
echo -n "\$AllowedSender TCP, " >> AllowedSender.txt
echo "$CLIENT_SERVER_IP" >> AllowedSender.txt
echo -n "\$AllowedSender UDP, " >> AllowedSender.txt
echo "$CLIENT_SERVER_IP" >> AllowedSender.txt
cat AllowedSender.txt >> /etc/rsyslog.d/99-logstashelastic.conf
rm AllowedSender.txt
# Rsyslog Restart
sudo service rsyslog restart

# Restart all services
sudo service kibana restart
sudo service elasticsearch restart
sudo service logstash restart
sudo service filebeat restart

# Done
