#!/bin/bash

# Define variables (custom paths)
APACHE_CONF="/opt/homebrew/etc/httpd/httpd.conf"
VHOSTS_CONF="/opt/homebrew/etc/httpd/extra/httpd-vhosts.conf"
DOC_ROOT="/opt/homebrew/var/www"
HTPASSWD_FILE="/opt/homebrew/etc/httpd/.htpasswd"

# Install Apache using Homebrew
echo "Installing Apache..."
# brew install httpd

# Create directories and html files
echo "Creating directories and html files..."
mkdir -p "$DOC_ROOT/site1" "$DOC_ROOT/site2"
echo "<h1>Welcome to site1.local</h1>" > "$DOC_ROOT/site1/index.html"
echo "<h1>Welcome to site2.local</h1>" > "$DOC_ROOT/site2/index.html"
echo "<h1>This is a custom 404 error page</h1>" > "$DOC_ROOT/site1/404.html"
echo "<h1>This is a custom 404 error page</h1>" > "$DOC_ROOT/site1/404.html"

# Enable Virtual Hosts in Apache configuration
if grep -q "^#Include $VHOSTS_CONF" "$APACHE_CONF"
then
    echo "Enabling Virtual Hosts in configuration file..."
    sed -i '' "s|^#Include $VHOSTS_CONF|Include $VHOSTS_CONF|" "$APACHE_CONF"
fi

# Enable basic authentication in Apache configuration
if grep -q "^#LoadModule auth_basic_module" "$APACHE_CONF"
then
    echo "Enabling mod_auth_basic..."
    sed -i '' "s|^#LoadModule auth_basic_module|LoadModule auth_basic_module|" "$APACHE_CONF"
fi

# Enable alias_module in Apache configuration for custom error pages
if grep -q "^#LoadModule vhost_alias_module" "$APACHE_CONF"
then
    echo "Enabling vhosts_alias_module..."
    sed -i '' "s|^#LoadModule vhost_alias_module|LoadModule vhost_alias_module|" "$APACHE_CONF"
fi

# Create username and password for basic authentication
echo "Creating a username and password for basic authentication..."
read -p "Enter a username: " USERNAME
read -s -p "Enter a password: " PASSWORD
echo
sudo htpasswd -bc "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"
echo "Password file created at $HTPASSWD_FILE"

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

# Step 10: Restart Apache to apply changes
echo "Restarting Apache..."
brew services restart httpd
echo "Setup complete! Try accessing site1.local:8080, site2.local:8080 and a non-existent page in your browser."
