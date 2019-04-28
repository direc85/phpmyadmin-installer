# PHPMyAdmin install script for Debian/Ubuntu

Inspired by the fact that the Debian and Ubuntu packages still ship version 4.4.6 (as of April 2019) and doesn't even run on PHP 7. Please see this bug report for example: https://bugs.launchpad.net/ubuntu/+source/phpmyadmin/+bug/1767361

### This is a blunt and experimental script.

### Use at your own risk.

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

This script is provided on an 'as is' basis, without warranty of any kind. Use at your own risk! Under no circumstances shall the author(s) or contributor(s) be liable for damages resulting directly or indirectly from the use or non-use of this script.

No, seriously. Read the script through before you try it out.

This script is licensed under GPL2.

(c) 2019 Matti Viljanen (direc85)
