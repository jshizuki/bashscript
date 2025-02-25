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

Create directories and html files
echo "Creating directories and html files..."
mkdir -p "$DOC_ROOT/site1" "$DOC_ROOT/site2"
echo "<h1>Welcome to site1.localhost</h1>" > "$DOC_ROOT/site1/index.html"
echo "<h1>Welcome to site2.localhost</h1>" > "$DOC_ROOT/site2/index.html"
echo "<h1>This is a custom 404 error page</h1>" > "$DOC_ROOT/site1/404.html"
echo "<h1>This is a custom 404 error page</h1>" > "$DOC_ROOT/site2/404.html"
cp -r /Users/jshizuki/Downloads/html5up-dimension /opt/homebrew/var/www/site3

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

# VIRTUAL HOST: Enable Virtual Hosts in Apache configuration
enable_apache_config "Include $VHOSTS_CONF" "Enabling Virtual Hosts in configuration file..."

# BASIC AUTH: Enable basic authentication in Apache configuration
enable_apache_config "LoadModule auth_basic_module" "Enabling mod_auth_basic..."

# CUSTOM ERROR PAGE: Enable alias_module in Apache configuration for custom error pages
enable_apache_config "LoadModule vhost_alias_module" "Enabling vhosts_alias_module..."

# HTTPS: Enable the below in Apache configuration for HTTPS
enable_apache_config "LoadModule ssl_module" "Enabling ssl_module..."
enable_apache_config "LoadModule socache_shmcb_module" "Enabling socache_shmcb_module..."
enable_apache_config "Include $SSL_CONF" "Enabling SSL configuration in configuration file..."

# CACHING: Enable mod_expires in Apache configuration for caching
enable_apache_config "LoadModule expires_module" "Enabling mod_expires..."
enable_apache_config  "LoadModule headers_module" "Enabling mod_headers..."

# Get username and password from environment variables for basic authentication
USERNAME="${APACHE_USERNAME:-}"
PASSWORD="${APACHE_PASSWORD:-}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] # Check if variables are empty
then
    # In the terminal, run: export APACHE_USERNAME="username" APACHE_PASSWORD="password" or else it'll exit
    echo "Error: APACHE_USERNAME and APACHE_PASSWORD environment variables must be set."
    exit 1
fi

echo "Creating a username and password for basic authentication..."

if [ -f "$HTPASSWD_FILE" ]
then
    echo "Password file already exists. Skipping..."
else
    sudo htpasswd -bc "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
    echo "Password file created at $HTPASSWD_FILE"
fi

# Configure Apache Virtual Hosts for multi-site hosting, authentication and client-side caching
echo "Configuring Virtual Hosts..."

cat <<EOL > "$VHOSTS_CONF"
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

<VirtualHost *:8080>
    ServerName site3.localhost
    DocumentRoot "$DOC_ROOT/site3"
    <Directory "$DOC_ROOT/site3">
        AllowOverride All
        Require all granted

        <IfModule mod_expires.c>
            ExpiresActive On
            ExpiresDefault "access plus 1 hour"
        </IfModule>

        <IfModule mod_headers.c>
            Header set Cache-Control "max-age=10, immutable"
            Header unset ETag
        </IfModule>
    </Directory>
</VirtualHost>
EOL

# Issue a self-signed SSL certificate
echo "Creating a self-signed SSL certificate..."
if
    [ -f "$APACHE_ROOT/server.crt" ] && [ -f "$APACHE_ROOT/server.key" ]
then
    echo "SSL certificate and key already exist. Skipping..."
else
    openssl genrsa -out "$APACHE_ROOT/server.key"
    openssl req -new -key "$APACHE_ROOT/server.key" -out "$APACHE_ROOT/server.csr"
    openssl x509 -req -days 365 -in "$APACHE_ROOT/server.csr" -signkey "$APACHE_ROOT/server.key" -out "$APACHE_ROOT/server.crt"
fi

# Configure SSL in Apache configuration
echo "Configuring SSL for site1..."

echo "Commenting out the entire SSL VirtualHost block..."
sed -i '' '/<VirtualHost _default_:8443>/,/<\/VirtualHost>/ s/^/#/' "$SSL_CONF"

cat <<EOL >> "$SSL_CONF"
<VirtualHost _default_:8443>

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
echo "Setup complete! Try accessing site1.localhost:8080, site2.localhost:8080, site1.localhost:8443 and a non-existent page in your browser."
