# Log Collection Server 

### Rsyslog + Filebeat + Logstash + ElasticSearch

Installation script to automatically configure an Ubuntu 16.04 x64 server with rsyslog reception, filebeat, logstash and elasticsearch.

The basic setup of this configuration relies on the following technologies:

- Rsyslog with UDP/TCP reception, configured on port 514 but can be edited through the script.
- Filebeat (Elastic.io) for file monitoring/collection of /var/syslog.
- Logstash (Elastic.io) as transport to ElasticSearch.
- ElasticSearch (Elastic.io) as document store.

Kibana is not installed, this is strictly for processing log data and not for the visualization component.

### Basic Flow

CLIENT SERVER (REMOTE) >> UDP or TCP on port 514 Syslog Events >> LOG SERVER (This Script) >> Rsyslog UDP or TCP 514 Receptor >> /var/syslog/ >> Filebeat >> Logstash >> Elasticsearch

### Not covered in this script

- Elasticsearch cluster.
- CLIENT SERVER filebeat directly to LOG SERVER logstash. Can be configured, but chose rsyslog as transport. SSL certificates however ARE generated by this script and placed on /etc/pki/tls/certs/ (logstash-forwarder.crt), so move this over to the client after installing filebeat, and configure the YAML configuration file to include TLS and the certificate path if you want to use filebeat for transport instead of rsyslog.
- Multi client server support. The script will only ask for ONE client server IP. To configure more IPs edit the rsyslog configuration file under /etc/rsyslog.d/ to allow other senders over TCP or UDP transports (i.e.: "$AllowSender UDP, 1.2.3.4").

### Note
Remember to chmod +x install.sh to make it executable! Then run ./install.sh

### Bigger Note 
Java + Logstash + ElasticSearch will consume a good deal of memory so micro instances (i.e.: 512 MB RAM) are not recommended! Make sure your server is properly sized. Recommend at least 4GB of memory. For production use, consult Elastic.io documentation for tunables on filebeat, logstash and ElasticSearch, and size your partitions properly. 

### Even Bigger Note
Also... if for production use... use filebeat for log shipment rather than rsyslog - the $AllowSender feature in rsyslog is a primitive way of blocking IPs from sending logs to your log server, and bad packets, the last thing you want is your server to get a DoS, or a flood of bad data taking up your entire disk space, or even worse, your juicy network logs to be harvested by bad peeps! So, at the very least use UFW to restrict incoming connections, OR use filebeat for secured TLS connections between client/server. 

If this is a private/on-premise + cloud deployment: My personal recommended deployment for this is a client side VM with rsyslog open on UDP/TCP, have local servers dump logs to this server, then create a reverse SSH tunnel to the cloud server from the client side server, and pass traffic through the tunnel (local forward:port > remote:port) through filebeat or rsyslog - don't risk it.

### Usage

On the server receiving all the logs, download this script and run:
> chmod +x install.sh

> ./install.sh

Or you can also download the raw file from GitHub and run the install script automatically:
> curl -sSL https://raw.githubusercontent.com/danucalovj/logcollectionserver/master/install.sh | sh

Type in the client system's IP that will be sending logs to this server. Note: This is the NAT IP if behind a firewall.

When done, test Logstash and ElasticSearch:
> sudo service logstash configtest

> curl -X GET 'http://localhost:9200'

Run netstat -an | grep 514 and make sure your server is listening on 514

On client server, make sure you've configured rsyslog to send logs to this server by creating a configuration under /etc/rsyslog.d/<XX-YOUR_CONFIGURATION_FILE.conf>. Configure this server IP as a rsyslog server:
> \*.\*   @<SERVER_IP>:514

Then restart rsyslog on the client server:
> sudo service rsyslog restart

All set! Any logs that end up on your client system (whether local or forwarded from other servers) are shipped to your ElasticSearch server. Remember to configure the client server for rsyslog reception if ingesting logs from other servers/devices on the local network.
