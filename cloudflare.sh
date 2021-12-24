#Get info from user
echo "Name of domain? (without www.)"
read DOM
echo "Cloudflare email?"
read MAIL
echo "Cloudflare API key?"
read KEY

#Install dependancies
sudo apt-get install ufw nginx software-properties-common certbot python3-certbot-nginx python3-certbot-dns-cloudflare -y

#Setup UFW firewall
sudo ufw disable
echo "y" | sudo ufw reset
sudo ufw allow ssh
sudo ufw allow ftp
URLS="$(wget -qO - https://www.cloudflare.com/ips-v4)\n$(wget -qO - https://www.cloudflare.com/ips-v6)"
for IP in $(echo -e "$URLS")
do
	sudo ufw allow from $IP to any port https
done
sudo ufw enable

#Configure NGINX
sudo bash -c "cat <<-EOF> /etc/nginx/sites-available/default
##
# You shoud look at the following URL's in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# https://www.nginx.com/resources/wiki/start/
# https://www.nginx.com/resources/wiki/start/topics/tutorials/config_pitfalls/
# https://wiki.debian.org/Nginx/DirectoryStructure
#
# In most cases, administrators will remove this file from sites-enabled/ ans
# leave it as reference inside of sites-available where it will continue to be
# updated by the nginx packaging team.
#
# This file will automatically load configuration files provided by other
# applications, such as Drupal or Wordpress. These applications will be made
# available underneath a path with that package name, such as /drupal18.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##

server {
if (\\\$host = www.$DOM) {
return 301 https://\\\$host\\\$request_uri;
}
if (\\\$host = $DOM) {
return 301 https://\\\$host\\\$request_uri;
}

listen 80;
server_name $DOM www.$DOM;
return 404;
}

server {
listen 443 ssl;
server_name $DOM www.$DOM;
client_max_body_size 100M;

location /robots.txt {
	return 200 \"User-agent: *
Disallow:\";
}

location / {
proxy_pass http://localhost:8080;
proxy_set_header Host \\\$host;
real_ip_header CF-Connecting-IP;
client_max_body_size 100M; #Max file size for users to upload

if (\\\$request_uri ~ ^/(.*)(?:catalog)\\\$) {
	return 302 /\\\$1catalog.html;
}

}

	ssl_certificate /etc/letsencrypt/live/$DOM/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$DOM/privkey.pem;
}
EOF"

sudo bash -c "cat <<-EOF> /etc/logrotate.d/nginx
/var/log/nginx/*.log {
	daily
	missingok
	rotate 0
	compress
	delaycompress
	notifempty
	create 0640 www-data adm
	sharedscripts
	prerotate
		if [ -d /etc/logrotate.d/httpd-prerotate ]; then \\\ 
			run-parts /etc/logrotate.d/httpd-prerotate; \\\ 
		fi \\\ 
	endscript
	postrotate
		invoke-rc.d nginx rotate >/dev/null 2>&1
	endscript
}
EOF"

SETREAL=""
for IP in $(echo -e "$URLS")
do
	SETREAL+="\tset_real_ip_from $IP;\n"
done
SETREAL=$(echo -e "${SETREAL::-2}")


sudo bash -c "cat <<-EOF> /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*conf;

events {
		worker_connections 768;
		# multi_accept on;
}

http {
	##
	# Basic Settings
	##
	
	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	# server_tokens off;
	
	# server_names_hash_bucket_size 64;
	# Server_name_in_redirect off;
	
	include /etc/nginx/mime.types;
	default_type application/octet-stream;
	
	##
	# SSL Settings
	##
	
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; #Dropping SSLv3, ref: POODLE
	ssl_prefer_server_ciphers on;
	
	##
	# Logging Settings
	##
	
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;
	
	##
	# Gzip Settings
	##
	
	gzip on;
	
	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript
	
	##
	# Virtual Host Configs
	##
	
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
	
$SETREAL
	
	# Use any of the following two
	real_ip_header CF-Connecting-IP;
	#real_ip_header X-Forward-For;
	
}
EOF"

sudo systemctl enable nginx

#Certbot config
sudo mkdir /root/.secrets/
sudo bash -c "cat <<-EOF> /root/.secrets/cloudflare.ini
dns_cloudflare_email = $MAIL
dns_cloudflare_api_key = $KEY
EOF"
sudo chmod 0700 /root/.secrets/
sudo chmod 0400 /root/.secrets/cloudflare.ini
{ echo "$MAIL";
  echo "Y";
  echo "N";
} | sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/cloudflare.ini -d $DOM -d www.$DOM
sudo certbot renew --dry-run
sudo systemctl start nginx
