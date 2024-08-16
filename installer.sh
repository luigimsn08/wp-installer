#!/bin/bash

# Funktion zur Generierung eines zufälligen Datenbank-Benutzernamens
generate_db_username() {
    echo "admin_$(shuf -i 100-999 -n 1)"
}

# Funktion zur Generierung eines zufälligen Passworts
generate_password() {
    echo "$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
}

# Funktion zur Installation von Apache, MariaDB, PHP und erforderlichen PHP-Erweiterungen
install_lamp_stack() {
    sudo apt update
    sudo apt install apache2 mariadb-server php php-mysql libapache2-mod-php php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
}

# Funktion zur Konfiguration der MariaDB-Datenbank für WordPress
configure_mariadb() {
    local db_user=$(generate_db_username)
    local db_password=$(generate_password)
    
    sudo mysql -e "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
    sudo mysql -e "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';"
    sudo mysql -e "GRANT ALL ON wordpress.* TO '${db_user}'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"
    
    echo "Datenbank und Benutzer für WordPress konfiguriert."
    echo "Benutzer: ${db_user}"
    echo "Passwort: ${db_password}"
    
    WORDPRESS_DB_USER=$db_user
    WORDPRESS_DB_PASSWORD=$db_password
}

# Funktion zur Installation von WordPress
install_wordpress() {
    cd /tmp
    curl -O https://wordpress.org/latest.tar.gz
    tar xzvf latest.tar.gz
    sudo cp -a /tmp/wordpress/. /var/www/html
    sudo rm /var/www/html/index.html
    sudo chown -R www-data:www-data /var/www/html
    sudo find /var/www/html/ -type d -exec chmod 750 {} \;
    sudo find /var/www/html/ -type f -exec chmod 640 {} \;
    
    # Aktualisieren der WordPress-Konfigurationsdatei wp-config.php
    sudo mv /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sudo sed -i "s/database_name_here/wordpress/g" /var/www/html/wp-config.php
    sudo sed -i "s/username_here/${WORDPRESS_DB_USER}/g" /var/www/html/wp-config.php
    sudo sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/g" /var/www/html/wp-config.php
    
    echo "WordPress wurde erfolgreich installiert."
}

# Funktion zur Installation von phpMyAdmin
install_phpmyadmin() {
    cd /tmp
    curl -O https://files.phpmyadmin.net/phpMyAdmin/5.1.0/phpMyAdmin-5.1.0-all-languages.tar.gz
    tar xzvf phpMyAdmin-5.1.0-all-languages.tar.gz
    sudo mv phpMyAdmin-5.1.0-all-languages /usr/share/phpmyadmin
    sudo tee /etc/apache2/conf-available/phpmyadmin.conf <<-EOF
Alias /phpmyadmin /usr/share/phpmyadmin
<Directory /usr/share/phpmyadmin>
    Options FollowSymLinks
    DirectoryIndex index.php
    AllowOverride All
</Directory>
EOF
    sudo a2enconf phpmyadmin.conf
    sudo systemctl reload apache2
    
    echo "phpMyAdmin wurde erfolgreich installiert."
}

# Funktion zum Erstellen eines Website-Backups
create_website_backup() {
    local backup_dir="/var/backups/wordpress_backup_$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p $backup_dir
    
    sudo cp -r /var/www/html $backup_dir
    sudo mysqldump wordpress > $backup_dir/wordpress.sql
    
    echo "Website-Backup wurde erfolgreich erstellt und im Verzeichnis $backup_dir gespeichert."
}

# Funktion zum Entfernen eines Website-Backups
remove_website_backup() {
    local backup_list=$(ls -d /var/backups/wordpress_backup_* 2>/dev/null)
    if [ -z "$backup_list" ]; then
        echo "Es wurden keine Backups gefunden."
        return
    fi
    
    echo "Verfügbare Backups:"
    select backup in $backup_list; do
        if [ -n "$backup" ]; then
            sudo rm -rf "$backup"
            echo "Das Backup wurde erfolgreich entfernt."
            break
        fi
    done
}

# Funktion zum Wiederherstellen eines Website-Backups
restore_website_backup() {
    local backup_list=$(ls -d /var/backups/wordpress_backup_* 2>/dev/null)
    if [ -z "$backup_list" ]; then
        echo "Es wurden keine Backups gefunden."
        return
    fi
    
    echo "Verfügbare Backups:"
    select backup in $backup_list; do
        if [ -n "$backup" ]; then
            local restore_dir="/var/www/html_restored_$(date +%Y%m%d_%H%M%S)"
            sudo mkdir -p $restore_dir
            sudo cp -r $backup/html/* $restore_dir
            sudo mysql wordpress < $backup/wordpress.sql
            echo "Website-Backup wurde erfolgreich wiederhergestellt."
            break
        fi
    done
}

# Installation und Konfiguration starten
install_lamp_stack
configure_mariadb
install_wordpress
install_phpmyadmin

echo "Alle Prozesse abgeschlossen."
