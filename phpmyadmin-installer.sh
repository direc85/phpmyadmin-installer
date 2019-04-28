#!/bin/bash
README="PHPMyAdmin install script for Debian/Ubuntu

Inspired by the fact that the Debian and Ubuntu packages
still ship version 4.4.6 (as of April 2019) and doesn't
even run on PHP 7. Please see this bug report for example:
https://bugs.launchpad.net/ubuntu/+source/phpmyadmin/+bug/1767361

    This is a blunt and experimental script.
    
      It may not result in a secure setup.

           Use at your own risk.

The script is tested on the following distributions:
 - Debian 10 Buster
 - Debian 9 Stretch
 - Debian 8 Jessie
 - Ubuntu 19.04 Disco Dingo
 - Ubuntu 18.04.2 LTS Bionic Beaver
 - Ubuntu 16.04.6 LTS Xenial Xerus
 - Ubuntu 14.04.6 LTS Trusty Thar

This script *SHOULD*...
 - detect your existing MariaDB and/or MySQL server and leave them alone
 - detect your existing PHPMyAdmin config.inc.php and use it instead
 - never remove MySQL or MariaDB

This script will...
 - remove your existing PHPMyAdmin installation and configuration
 - install Apache2, PHP and a few other packages
 - install MariaDB server if you don't have it (or MySQL server)
 - install and configure PHPMyAdmin from the official source
 - change the root password of the newly-installed MariaDB
 - delete and recreate database user 'phpmyadmin'@'localhost'

Contributions welcome: https://github.com/direc85/phpmyadmin-installer

This script is provided on an 'as is' basis, without warranty of any kind. Use
at your own risk! Under no circumstances shall the author(s) or contributor(s)
be liable for damages resulting directly or indirectly from the use or non-use
of this script.

No, seriously. Read the script through before you try it out.

This script is licensed under GPL2.

(c) 2019 Matti Viljanen (direc85)"

#####
# Configure the following options:
#####

# URL to get the released zip file (29.04.2019)
# This script can not yet handle the
# upcoming PHPMyAdmin 5.0, which requires PHP 7.1.0
# https://phpmyadmin.readthedocs.io/en/latest/faq.html#faq1-31
PMA_URL=https://files.phpmyadmin.net/phpMyAdmin/4.8.5/phpMyAdmin-4.8.5-all-languages.zip

# The one directory that the zip contains (should be the filename without ".zip")
PMA_DIR=phpMyAdmin-4.8.5-all-languages

# Set password for user 'myphpadmin'
# You really should set this to something strong...
PHPMYNEWPW=PHPMyPass

# MySQL/MariaDB root password.
# On new installs, the default is empty
DBROOTPW=

# New MariaDB/MySQL database root user password.
# Skipped if empty or not set, or if server is already installed.
# You really should set this to something strong...
DBROOTNEWPW=SQLRootPass

# Install MariaDB (MySQL) server, your call.
# Skipped if empty or not set, or if server is already installed.
#DBSERVER=mysql-server
DBSERVER=mariadb-server

#####
# Do not touch these, unless you **really** know what you are doing!
#####

RANDOMSTRING=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
WORKDIR=/tmp/phpmyadmin-$RANDOMSTRING
INSTALLDIR=/usr/share/phpmyadmin
CACHEDIR=/var/lib/phpmyadmin
CONFIGDIR=/etc/phpmyadmin

#####
# Let's get down to business!
#####

if [ $(id -u) -ne 0 ]; then echo "Run this script with root privileges."; exit 1; fi
which lsb_release >/dev/null
if [ $? -ne 0 ]; then echo "lsb_release not found, can't continue."; exit 1; fi
which apt-get >/dev/null
if [ $? -ne 0 ]; then echo "apt-get not found, can't continue."; exit 1; fi
which wget >/dev/null
if [ $? -ne 0 ]; then echo "wget not found, can't continue."; exit 1; fi
which egrep >/dev/null
if [ $? -ne 0 ]; then echo "egrep not found, can't continue."; exit 1; fi

############### APT BLOCK ###############

echo "Distribution: $(lsb_release -sd) ($(lsb_release -sc))"
case $(lsb_release -sc) in
    buster)
        PACKAGES="unzip apache2 libapache2-mod-php php php-mysqli php-pear php-zip \
            php-bz2 php-mbstring php-xml php-php-gettext php-phpseclib php-curl php-gd"
        ;;
    stretch|buster|bionic|disco)
        PACKAGES="unzip apache2 libapache2-mod-php php php-mysqli php-pear php-zip \
            php-bz2 php-tcpdf php-mbstring php-xml php-php-gettext php-phpseclib php-curl php-gd"
        ;;
    xenial)
        PACKAGES="unzip apache2 libapache2-mod-php php php-mysqli php-pear php-zip \
            php-bz2 php-tcpdf php-mbstring php-mcrypt php-xml php-gettext php-phpseclib php-curl php-gd"
        ;;
    jessie|trusty)
        PACKAGES="unzip apache2 libapache2-mod-php5 php5 php5-mysql php-tcpdf php-gettext php-seclib php5-curl php5-gd"
        ;;
    *)
        echo "Your distribution is not yet supported - perhaps it's just not listed yet."
        echo "Contributions welcome: https://github.com/direc85/phpmyadmin-installer"
        exit 1
        ;;
esac

if [ $(apt list --installed 2>/dev/null | grep phpmyadmin | wc -l) -eq 1 ]; then
    echo "Purging phpmyadmin package..."
    apt-get remove -y --purge phpmyadmin >/dev/null
fi

if [ $(apt list --installed 2>/dev/null | egrep "mariadb-server|mysql-server" | wc -l) -ge 1 ]; then
    echo "MariaDB/MySQL server detected."
    DBSERVER=
    DBROOTNEWPW=
fi

echo "Installing packages (this may take some time)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES $DBSERVER >/dev/null
if [ $? -ne 0 ]; then
    echo "Error installing packages using apt-get"
    echo "Command: apt-get install -y $PACKAGES"
    exit 1
fi

############### PHPMYADMIN BLOCK ###############

rm -rf $WORKDIR
mkdir $WORKDIR
cd $WORKDIR

echo "Downloading PHPMyAdmin..."
wget --quiet $PMA_URL -O phpmyadmin.zip
if [ $? -ne 0 ]; then
    echo "Error downloading PHPMyAdmin zip archive."
    echo "URL: $PMA_URL"
    exit 1
fi 

echo "Decompressing PHPMyAdmin..."
unzip -q phpmyadmin.zip
if [ $? -ne 0 ]; then
    echo "Error extracting PHPMyAdmin zip archive."
    exit 1
fi

if [ ! -d "$PMA_DIR" ]; then
    echo "Error locating PHPMyAdmin source directory."
    echo "Please check $WORKDIR"
    echo "and update PMA_DIR variable in the script."
    exit 1
fi

if [[ -f "$CONFIGDIR/config.inc.php" && ! -L "$CONFIGDIR/config.inc.php" ]]; then
    echo "Existing configure found in $CONFIGDIR/config.inc.php"
elif [[ -f "$INSTALLDIR/config.inc.php" && ! -L "$INSTALLDIR/config.inc.php" ]]; then
    echo "Existing configure found in $INSTALLDIR/config.inc.php"
    echo "Moving it to $CONFIGDIR/config.inc.php.$RANDOMSTRING"
    cp "$INSTALLDIR/config.inc.php" "$CONFIGDIR/config.inc.php.$RANDOMSTRING"
else
    echo "Creating $CONFIGDIR/config.inc.php..."
    echo "
    <?php
        \$cfg['blowfish_secret'] = '$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)';
        \$cfg['TempDir'] = '$CACHEDIR/tmp';
    ?>" > config.inc.php

    chown root:root config.inc.php
    chmod 640 config.inc.php
    mkdir -p "$CONFIGDIR"
    mv "config.inc.php" "$CONFIGDIR/config.inc.php"
    ln -s "$CONFIGDIR/config.inc.php" "$PMA_DIR/config.inc.php"
fi

if [ $(grep "blowfish_secret" "$CONFIGDIR/config.inc.php" | grep -v "\/\/" | wc -l) -lt 1 ]; then
    echo "Warning: $CONFIGDIR/config.inc.php doesn't seem to contain"
    echo "         \$cfg['blowfish_secret'] option."
    echo "         You may have to configure this yourself."
fi

echo "Installing PHPMyAdmin to $INSTALLDIR..."
rm -rf $INSTALLDIR
chown root:root $PMA_DIR -R
mv $PMA_DIR $INSTALLDIR
if [ $? -ne 0 ]; then
    echo "Error moving $PMA_DIR to $INSTALLDIR"
    exit 1
fi 

if [ -d $CACHEDIR ]; then
    echo "Removing old PHPMyAdmin cache..."
    rm -rf $CACHEDIR
fi

echo "Creating cache directories in $CACHEDIR..."
mkdir -p $CACHEDIR/tmp $CACHEDIR/cache
chown www-data:www-data $CACHEDIR -R
chmod 770 $CACHEDIR

############### DATABASE BLOCK ###############

echo "USE mysql;" > test.sql
if [ ! -z "$DBROOTPW" ]; then
    DBROOTPW=-p$DBROOTPW
fi
mysql -uroot $DBROOTPW < test.sql
if [ $? -ne 0 ]; then
    echo "Invalid database root password provided."
    exit 1
fi

if [ ! -z "$DBROOTNEWPW" ]; then
    echo "Changing database 'root'@'localhost' password..."
    echo "USE mysql;
        UPDATE user
            SET password=PASSWORD('$DBROOTNEWPW')
            WHERE User='root'
            AND Host = 'localhost';" > root_pw.sql
    mysql -uroot $DBROOTPW < root_pw.sql
    if [ $? -ne 0 ]; then
        echo "Error changing password."
        exit 1
    fi
    DBROOTPW=-p$DBROOTNEWPW
fi

echo "Create database user 'phpmyadmin'..."
echo "
    USE mysql;
    DROP PROCEDURE IF EXISTS mysql.pma_user_create;
    DELIMITER \$\$
    CREATE PROCEDURE mysql.pma_user_create()
    BEGIN
        DECLARE usercount BIGINT DEFAULT 0 ;
        SELECT COUNT(*)
        INTO usercount
        FROM mysql.user
            WHERE User = 'phpmyadmin' and  Host = 'localhost';
        IF usercount > 0 THEN
            DROP USER 'phpmyadmin'@'localhost';
        END IF;
        CREATE USER 'phpmyadmin'@'localhost';
        UPDATE user
            SET password=PASSWORD('$PHPMYNEWPW')
            WHERE User='phpmyadmin'
            AND Host = 'localhost';
        GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost';
        FLUSH PRIVILEGES;
    END ;\$\$
    DELIMITER ;
    CALL mysql.pma_user_create() ;
    DROP PROCEDURE IF EXISTS mysql.pma_user_create;
    " > create_phpmyadmin_user.sql
mysql -uroot $DBROOTPW < create_phpmyadmin_user.sql
if [ $? -ne 0 ]; then
    echo "Creating database user failed."
    exit 1
fi
rm create_phpmyadmin_user.sql

mysql -uphpmyadmin -p$PHPMYNEWPW < $INSTALLDIR/sql/create_tables.sql
if [ $? -ne 0 ]; then
    echo "Creating PHPMyAdmin database failed."
    exit 1
fi

############### APACHE BLOCK ###############

if [ $(grep -lr "$INSTALLDIR" /etc/apache2/sites-available | wc -l) -gt 0 ]; then
    echo "PHPMyAdmin site already enabled."
else
    echo "Enabling PHPMyAdmin site in Apache2..."
    echo "Alias /phpmyadmin /usr/share/phpmyadmin
    <Directory /usr/share/phpmyadmin>
        DirectoryIndex index.php
        Options SymLinksIfOwnerMatch
    </Directory>
    <Directory /usr/share/phpmyadmin/templates>
        Require all denied
    </Directory>
    <Directory /usr/share/phpmyadmin/libraries>
        Require all denied
    </Directory>
    <Directory /usr/share/phpmyadmin/setup/lib>
        Require all denied
    </Directory>" > phpmyadmin.conf

    mv phpmyadmin.conf /etc/apache2/sites-available/
    a2ensite phpmyadmin >/dev/null
    echo "Reloading Apache2..."
    service apache2 reload >/dev/null
fi

if [ ! -z "$DBROOTNEWPW" ]; then
    echo "Database root password set to \"$DBROOTNEWPW\""
elif [ -z "$DBROOTPW" ]; then
    echo "Database root password is empty. Please change it."
else
    echo "Database root password not changed."
fi
echo "PHPMyAdmin credentials set to \"phpmyadmin\" / \"$PHPMYNEWPW\""
