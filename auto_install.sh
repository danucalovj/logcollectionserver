#!/bin/bash
export CLIENT_SERVER_IP=<IP>
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
sudo apt-get -y install oracle-java8-installer
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
sudo apt-get update && sudo apt-get -y install elasticsearch
echo "network.host: localhost" >> /etc/elasticsearch/elasticsearch.yml
sudo service elasticsearch restart
sudo update-rc.d elasticsearch defaults 95 10
echo 'deb http://packages.elastic.co/logstash/2.2/debian stable main' | sudo tee /etc/apt/sources.list.d/logstash-2.2.x.list
sudo apt-get update && sudo apt-get -y install logstash
sudo mkdir -p /etc/pki/tls/certs
sudo mkdir /etc/pki/tls/private
sed -i 's/subjectAltName/#subjectAltName/g' /etc/ssl/openssl.cnf
echo -n "subjectAltName = IP: " >> subjectAltName.txt
/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}' >> subjectAltName.txt
cat subjectAltName.txt >> /etc/ssl/openssl.cnf
rm subjectAltName.txt
sudo openssl req -config /etc/ssl/openssl.cnf -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout /etc/pki/tls/private/logstash-forwarder.key -out /etc/pki/tls/certs/logstash-forwarder.crt
echo "input {" > /etc/logstash/conf.d/02-beats-input.conf
echo "  beats {" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    port => 5044" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    ssl => true" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    ssl_certificate => \"/etc/pki/tls/certs/logstash-forwarder.crt"\" >> /etc/logstash/conf.d/02-beats-input.conf
echo "    ssl_key => \"/etc/pki/tls/private/logstash-forwarder.key"\" >> /etc/logstash/conf.d/02-beats-input.conf
echo "  }" >> /etc/logstash/conf.d/02-beats-input.conf
echo "}" >> /etc/logstash/conf.d/02-beats-input.conf
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
echo "output {" > /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "  elasticsearch {" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    hosts => [\"localhost:9200\"]" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    sniffing => true" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    manage_template => false" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    index => \"%{[@metadata][beat]}-%{+YYYY.MM.dd}\"" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "    document_type => \"%{[@metadata][type]}\"" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "  }" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
echo "}" >> /etc/logstash/conf.d/30-elasticsearch-output.conf
sudo service logstash configtest
sudo service logstash restart
sudo update-rc.d logstash defaults 96 9
echo "deb https://packages.elastic.co/beats/apt stable main" |  sudo tee -a /etc/apt/sources.list.d/beats.list
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get update && sudo apt-get -y install filebeat
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
curl -O https://gist.githubusercontent.com/thisismitch/3429023e8438cc25b86c/raw/d8c479e2a1adcea8b1fe86570e42abab0f10f364/filebeat-index-template.json
curl -XPUT 'http://localhost:9200/_template/filebeat?pretty' -d@filebeat-index-template.json
sudo service filebeat restart
sudo update-rc.d filebeat defaults 95 10
echo "module(load=\"imudp\")" >> /etc/rsyslog.d/99-logstashelastic.conf                                                                             
echo "input(type=\"imudp\" port=\"514\")" >> /etc/rsyslog.d/99-logstashelastic.conf
echo "module(load=\"imtcp\")" >> /etc/rsyslog.d/99-logstashelastic.conf                                                             
echo "input(type=\"imtcp\" port=\"514\")" >> /etc/rsyslog.d/99-logstashelastic.conf
echo -n "\$AllowedSender TCP, " >> AllowedSender.txt
echo "$CLIENT_SERVER_IP" >> AllowedSender.txt
echo -n "\$AllowedSender UDP, " >> AllowedSender.txt
echo "$CLIENT_SERVER_IP" >> AllowedSender.txt
cat AllowedSender.txt >> /etc/rsyslog.d/99-logstashelastic.conf
rm AllowedSender.txt
sudo service rsyslog restart
echo "DONE!"
