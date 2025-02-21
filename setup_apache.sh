#!/bin/bash

# Define variables
APACHE_ROOT="/opt/homebrew/etc/httpd"
APACHE_CONF="/opt/homebrew/etc/httpd/httpd.conf"
VHOSTS_CONF="/opt/homebrew/etc/httpd/extra/httpd-vhosts.conf"
DOC_ROOT="/opt/homebrew/var/www"
HTPASSWD_FILE="/opt/homebrew/etc/httpd/.htpasswd"
SSL_CONF="/opt/homebrew/etc/httpd/extra/httpd-ssl.conf"

# Install Apache using Homebrew if not already installed
if ! brew list httpd &> /dev/null
then
    echo "Installing Apache..."
    brew install httpd
else
    echo "Apache is already installed. Skipping installation..."
fi

# Create directories and html files
echo "Creating directories and html files..."
mkdir -p "$DOC_ROOT/site1" "$DOC_ROOT/site2"
echo "<h1>Welcome to site1.localhost</h1>" > "$DOC_ROOT/site1/index.html"
echo "<h1>Welcome to site2.localhost</h1>" > "$DOC_ROOT/site2/index.html"
echo "<h1>This is a custom 404 error page</h1>" > "$DOC_ROOT/site1/404.html"
echo "<h1>This is a custom 404 error page</h1>" > "$DOC_ROOT/site2/404.html"

enable_apache_config() {
  local pattern="$1"
  local message="$2"

  if grep -q "^#$pattern" "$APACHE_CONF";
  then
    echo "$message"
    sed -i '' "s|^#$pattern|$pattern|" "$APACHE_CONF"
  else
    echo "$pattern is already enabled. Skipping..."
  fi
}

# Enable Virtual Hosts in Apache configuration
enable_apache_config "Include $VHOSTS_CONF" "Enabling Virtual Hosts in configuration file..."

# Enable basic authentication in Apache configuration
enable_apache_config "LoadModule auth_basic_module" "Enabling mod_auth_basic..."

# Enable alias_module in Apache configuration for custom error pages
enable_apache_config "LoadModule vhost_alias_module" "Enabling vhosts_alias_module..."

# Enable the below in Apache configuration for HTTPS
enable_apache_config "LoadModule ssl_module" "Enabling ssl_module..."
enable_apache_config "Include $SSL_CONF" "Enabling SSL configuration in configuration file..."
enable_apache_config "LoadModule socache_shmcb_module" "Enabling socache_shmcb_module..."

# Create username and password for basic authentication
USERNAME="${APACHE_USERNAME:-}"
PASSWORD="${APACHE_PASSWORD:-}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] # Check if variables are empty
then
    # In the terminal, run: export APACHE_USERNAME="username" APACHE_PASSWORD="password" or else it'll exit
    echo "Error: APACHE_USERNAME and APACHE_PASSWORD environment variables must be set."
    exit 1
fi

echo "Creating a username and password for basic authentication..."
sudo htpasswd -bc "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
echo "Password file created at $HTPASSWD_FILE"
# read -p "Enter a username: " USERNAME
# read -s -p "Enter a password: " PASSWORD
# echo
# sudo htpasswd -bc "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"

# Issue a self-signed SSL certificate
echo "Creating a self-signed SSL certificate..."
openssl genrsa -out "$APACHE_ROOT/server.key"
openssl req -new -key "$APACHE_ROOT/server.key" -out "$APACHE_ROOT/server.csr"
openssl x509 -req -days 365 -in "$APACHE_ROOT/server.csr" -signkey "$APACHE_ROOT/server.key" -out "$APACHE_ROOT/server.crt"

# Configure Apache Virtual Hosts for multi-site hosting and authentication
echo "Configuring Virtual Hosts..."
cat <<EOL >> "$VHOSTS_CONF"
<VirtualHost *:8080>
    ServerName site1.localhost
    DocumentRoot "$DOC_ROOT/site1"
    <Directory "$DOC_ROOT/site1">
        AuthType Basic
        AuthName "Restricted Access - Site 1"
        AuthUserFile "$HTPASSWD_FILE"
        AllowOverride All
        Require valid-user
    </Directory>
    ErrorDocument 404 "/404.html"
</VirtualHost>

<VirtualHost *:8080>
    ServerName site2.localhost
    DocumentRoot "$DOC_ROOT/site2"
    <Directory "$DOC_ROOT/site2">
        AuthType Basic
        AuthName "Restricted Access - Site 2"
        AuthUserFile "$HTPASSWD_FILE"
        AllowOverride All
        Require valid-user
    </Directory>
    ErrorDocument 404 "/404.html"
</VirtualHost>
EOL

# Configure SSL in Apache configuration
echo "Configuring SSL..."
cat <<EOL >> "$SSL_CONF"
<VirtualHost _default_:443>
    DocumentRoot "$DOC_ROOT/site1"
    ServerName site1.localhost
    SSLEngine on
    SSLCertificateFile "/opt/homebrew/etc/httpd/server.crt"
    SSLCertificateKeyFile "/opt/homebrew/etc/httpd/server.key"
</VirtualHost>
EOL

# Restart Apache to apply changes
echo "Restarting Apache..."
brew services restart httpd
echo "Setup complete! Try accessing site1.localhost:8080, site2.localhost:8080 and a non-existent page in your browser."
