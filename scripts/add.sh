#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root!"
    exit 1
fi

if [ $# -ne 3 ]; then
    echo "Usage: $0 <username> <password> <domain>"
    echo "Example: $0 pesho pass123 www.domain.com"
    exit 1
fi

USERNAME=$1
PASSWORD=$2
DOMAIN=$3

USER_HOME="/home/$USERNAME"
WEB_ROOT="$USER_HOME/www"
CGI_BIN="$USER_HOME/www-bin"
LOG_DIR="$USER_HOME/logs"
VHOST_FILE="/etc/apache2/sites-available/$USERNAME.conf"

WEBUSERSGROUP=webusers

echo "1. Create new user"

if id "$USERNAME" &>/dev/null; then
    echo "User exists, update password"
    echo "$USERNAME:$PASSWORD" | chpasswd
else
    useradd -m -d "$USER_HOME" -s /bin/false -U -G $WEBUSERSGROUP "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
fi

echo "2. Create directories"

mkdir -p "$WEB_ROOT/$DOMAIN" "$CGI_BIN" "$LOG_DIR"

echo "3. Create test index html"

cat > "$WEB_ROOT/$DOMAIN/index.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>$DOMAIN</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>$DOMAIN</h1>
    <p>Пробна заглавна страница.</p>
</body>
</html>
EOF

echo "4. Copy PHP-CGI binary"

cp /usr/bin/php-cgi8.2 "$CGI_BIN"

echo "5. Change permissions"

chown -R "$USERNAME:$USERNAME" "$USER_HOME"
chmod 755 "$USER_HOME" "$WEB_ROOT" "$CGI_BIN" "$LOG_DIR"

echo "6. Create Virtual Host"

cat > "$VHOST_FILE" <<EOF
<VirtualHost *:80>
        ServerName $DOMAIN
        ServerAlias www.$DOMAIN
        ServerAdmin webmaster@$DOMAIN
        DocumentRoot $WEB_ROOT/$DOMAIN
        DirectoryIndex index.html index.php

        <Directory "$WEB_ROOT/$DOMAIN">
                Options -Indexes
        </Directory>

        SuexecUserGroup $USERNAME $USERNAME

        ErrorLog $LOG_DIR/error.log
        CustomLog $LOG_DIR/access.log combined

        ScriptAlias /www-bin/ $CGI_BIN
        AddType application/x-httpd-php8 .php
        Action application/x-httpd-php8 /www-bin/php-cgi8.2
        php_admin_value open_basedir $WEB_ROOT/$DOMAIN
</VirtualHost>
EOF

echo "7. Enable Virtual Host & restart Apache"

a2ensite "$USERNAME.conf" &>/dev/null
systemctl reload apache2 &>/dev/null
