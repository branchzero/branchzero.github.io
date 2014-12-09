#!/bin/bash
#===========================================================================
# This library is free software; you can redistribute it and/or
# modify it under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation.
#===========================================================================
# Nginx usage:
# service nginx {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}
# MySQL usage:
# service mysqld  {start|stop|restart|reload|force-reload|status}  [ MySQL server options ]
# PHP-FPM usage:
# service php-fpm {start|stop|force-quit|restart|reload}
#
# MySQL configure file:
# /etc/my.cnf
# PHP configure files:
# /etc/php.ini
# /usr/local/php/etc/php-fpm.conf
# /etc/php-fpm.conf (symbolic link)
# Nginx configure file dir:
# /usr/local/nginx/conf/
# Nginx website configure file:
# /usr/local/nginx/conf/vhost/*.conf
#
# Web docs root:
# /home/www/
# MySQL data dir:
# /var/lib/mysql/
#===========================================================================
# Copyright (C) 2011 John Tse <xiejiayong@gmail.com> && 2014-2014 <branchzero@gmail.com>
# Support site: http://pkit.org
#===========================================================================


#   +----------------------------------------------------------------------+
#   | Functions                                                            |
#   +----------------------------------------------------------------------+

# service mangement
case $os in
centos)
	SET_SERVICE_STARTUP(){
		chkconfig --level 345 $1 on
	}
	;;
	
debian)
	SET_SERVICE_STARTUP(){
		update-rc.d -f $1 defaults
	}
	;;
esac

# $1 path_to_flag_file
# $2 message_to_print
draw_hand(){
	if [ -z $1 ]
	then
		FLAG=/tmp/_lnmp_flag
	else
		FLAG=/tmp/_lnmp_flag_$1
	fi

	i=1
	while [ ! -f $FLAG ]
	do
		case `expr $i % 4` in
			0) _char="|" ;;
			1) _char="/" ;;
			2) _char="-" ;;
			3) _char="\\" ;;
		esac
		printf "\33[?25l $2 \r$_char"
		
		sleep 0.05
		i=`expr $i + 1`
	done
	rm -f $FLAG
	printf "\r [\33[32mok\33[37m] $2\n"
}

set_flag(){
	if [ -z $1 ]
	then
		FLAG=/tmp/_lnmp_flag
	else
		FLAG=/tmp/_lnmp_flag_$1
	fi
	
	touch $FLAG
}

# $1 [msg1]
# $2 msg2...
x_msg(){
	printf "\33[?25l [\33[32m$1\33[37m] $2\n"
}

#   +----------------------------------------------------------------------+
#   | Prepare                                                              |
#   +----------------------------------------------------------------------+

echo "Installing MySQL + PHP + Nginx for "$os
echo "Support site: http://pkit.org"
echo 

export PATH=/usr/sbin:/sbin:$PATH

if [ $fetch_location = 'US' ]
then
	dl_loc_prefix = 'https://github.com/branchzero/pkit/raw/master/files/'
elif [ $fetch_location = 'CN' ]
then
	dl_loc_prefix = 'http://jd.pkit.org/files/'
fi

ngx_ver = '1.7.8'
php_ver = '5.6.3'
percona_ver = '5.6.21-70.1'
memcached_ver = '1.4.21'

# generate passwd
myrootpwd=`</dev/urandom tr -dc A-Za-z0-9 | head -c12`
wwwpwd=`</dev/urandom tr -dc A-Za-z0-9 | head -c12`
blowfish_secret=`</dev/urandom tr -dc A-Za-z0-9 | head -c12`

if [ -n $myrootpwd ] && [ -n $wwwpwd ] && [ -n $blowfish_secret ]
then
	x_msg "ok" "generat passwd ..."
fi


# pre-processing 

{
	unalias cp
	unalias rm

	if ! grep 127.0.0.1.*`hostname` /etc/hosts
	then
		sed -i "s#127.0.0.1#127.0.0.1  `hostname`#" /etc/hosts
	fi

	ulimit -SHn 65535

	# Close SELINUX
	setenforce 0 >  /dev/null  2>>/root/error.log
	sed -i 's/SELINUX=enforcing/#SELINUX=enforcing/' /etc/selinux/config
	echo 'SELINUX=disabled' >> /etc/selinux/config
}  >  /dev/null 2>>/root/error.log


for dir in /lib /usr/lib /usr/lib64 /usr/local/lib
do
	if [ -d $dir ] && [ ! `grep -l $dir '/etc/ld.so.conf'` ]
	then
		echo $dir >> /etc/ld.so.conf
	fi
done
ldconfig

# install package
{
	$INSTALL_PACKAGE $PACKAGE_F
	set_flag install_package
} > /dev/null 2>>/root/error.log &
draw_hand "install_package" "install packages ..."

# download files
rm -rf /tmp/pkit_dl_files
mkdir /tmp/pkit_dl_files
cd /tmp/pkit_dl_files

# download mysql first
{
	wget -q ${dl_loc_prefix}percona-server-$percona_ver.tar.gz
	tar xf percona-server-$percona_ver.tar.gz
	set_flag down_mysql
} > /dev/null 2>>/root/error.log &
draw_hand "down_mysql" "download mysql files ..."

# download background
{
	
	download_files="
	nginx-$ngx_ver.tar.gz
	php-$php_ver.tar.gz
	libzip-0.11.2.tar.gz
	imagick-3.2.0RC1.tar.gz
	memcache-3.0.8.tar.gz
	memcached-$memcached_ver.tar.gz
	libiconv-1.14.tar.gz
	libmcrypt-2.5.8.tar.gz
	nginx.conf
	nginx.init.$os
	"

	for file in $download_files
	do
		filename=`echo $file | tr -d [:space:]`
		wget -q $dl_loc_prefix$filename
		if echo $filename | grep tar.gz
		then
			tar xf $filename >  /dev/null  2>>/root/error.log
		fi
	done
	set_flag download_background
	
} > /dev/null 2>>/root/error.log &
x_msg "ok" "download other files background ..."


# yum background
{
	$INSTALL_PACKAGE $PACKAGE_B 
	set_flag install_packages_background
} > /dev/null 2>>/root/error.log &
x_msg "ok" "install other packages background ..."

# detect os arch
{
	if file /sbin/init | grep 32-bit
	then
		ARCH=32
	elif file /sbin/init | grep 64-bit
	then
		ARCH=64
	fi
}> /dev/null 2>&1

#   +----------------------------------------------------------------------+
#   | Install MySQL                                                        |
#   +----------------------------------------------------------------------+

# Add user
{
	groupadd mysql
	useradd -s /sbin/nologin -M -g mysql mysql
} > /dev/null 2>>/root/error.log

# Install MySQL
cd /tmp/pkit_dl_files
cd percona-server-$percona_ver
{
	cmake . -LAH \
	-DCMAKE_INSTALL_PREFIX=/usr/local/mysql/           \
	-DMYSQL_DATADIR=/var/lib/mysql                     \
	-DMYSQL_UNIX_ADDR=/tmp/mysqld.sock                 \
	-DCURSES_LIBRARY=/usr/lib/libcurses.so             \
	-DCURSES_INCLUDE_PATH=/usr/include                 \
	-DMYSQL_TCP_PORT=3306                              \
	-DEXTRA_CHARSETS=all                               \
	-DSYSCONFDIR=/etc/                                 \
	-DWITH_ZLIB=system                                 \
	-DWITH_READLINE=TRUE                               \

	set_flag config_mysql
} > /dev/null 2>>/root/error.log &
draw_hand "config_mysql" "config mysql files for compile ..."
{
	make
	set_flag compile_mysql
} > /dev/null 2>>/root/error.log &
draw_hand "compile_mysql" "compile mysql ..."
{
	make install
	set_flag install_mysql
} > /dev/null 2>>/root/error.log &
draw_hand "install_mysql" "install mysql ..."


ln -s /usr/local/mysql/lib/* /usr/lib/  > /dev/null 2>>/root/error.log

chown -R mysql:mysql /usr/local/mysql

cp -f support-files/my-medium.cnf /etc/my.cnf
sed -i 's#log-bin=mysql-bin# #' /etc/my.cnf
sed -i 's#binlog_format=mixed# #' /etc/my.cnf

{
	sh scripts/mysql_install_db  --basedir=/usr/local/mysql --datadir=/var/lib/mysql --user=mysql
	set_flag mysql_install_db
} > /dev/null 2>>/root/error.log &
draw_hand "mysql_install_db" "install mysql database ..."

cp -f support-files/mysql.server /etc/init.d/mysqld
chmod 755 /etc/init.d/mysqld

{
	service mysqld start
	set_flag start_mysql_service
} > /dev/null 2>>/root/error.log &
draw_hand "start_mysql_service" "start mysql service ..."


SET_SERVICE_STARTUP mysqld  > /dev/null 2>>/root/error.log

ln -s /usr/local/mysql/bin/myisamchk /usr/bin/  > /dev/null 2>>/root/error.log
ln -s /usr/local/mysql/bin/mysql /usr/bin/  > /dev/null 2>>/root/error.log
ln -s /usr/local/mysql/bin/mysqldump /usr/bin/  > /dev/null 2>>/root/error.log


/usr/local/mysql/bin/mysqladmin -u root password $myrootpwd  > /dev/null 2>>/root/error.log

mysql -u root -p$myrootpwd -h localhost <<QUERY_INPUT
use mysql;
delete from user where not (user='root') ;
delete from user where user='root' and password=''; 
drop database test;
DROP USER ''@'%';
flush privileges;
QUERY_INPUT

service mysqld stop

#   +----------------------------------------------------------------------+
#   | Install PHP                                                          |
#   +----------------------------------------------------------------------+

# Add user
/usr/sbin/groupadd www
/usr/sbin/useradd -g www www

# Wait for download
draw_hand "download_background" "wait while download background ..."

# Install libiconv
cd /tmp/pkit_dl_files
cd libiconv-1.14/
{
	./configure --prefix=/usr/local
	set_flag config_libiconv
} > /dev/null 2>>/root/error.log &
draw_hand "config_libiconv" "config libiconv files for compile ..."

{
	make
	set_flag compile_libiconv
} > /dev/null 2>>/root/error.log &
draw_hand "compile_libiconv" "compile libiconv ..."

{
	make install
	set_flag install_libiconv
} > /dev/null 2>>/root/error.log &
draw_hand "install_libiconv" "install libiconv ..."


# Install libmcrypt
cd /tmp/pkit_dl_files
cd libmcrypt-2.5.8/
{
	./configure --prefix=/usr
	set_flag config_libmcrypt
} > /dev/null 2>>/root/error.log &
draw_hand "config_libmcrypt" "config libmcrypt files for compile ..."
{
	make
	set_flag compile_libmcrypt
} > /dev/null 2>>/root/error.log &
draw_hand "compile_libmcrypt" "compile libmcrypt ..."
{
	make install
	set_flag install_libmcrypt
} > /dev/null 2>>/root/error.log &
draw_hand "install_libmcrypt" "install libmcrypt ..."
cd libltdl/
{
	./configure --enable-ltdl-install
	set_flag config_libltdl
} > /dev/null 2>>/root/error.log &
draw_hand "config_libltdl" "config libltdl files for compile ..."
{
	make
	set_flag compile_libltdl
} > /dev/null 2>>/root/error.log &
draw_hand "compile_libltdl" "compile libltdl ..."
{
	make install
	set_flag install_libltdl
} > /dev/null 2>>/root/error.log &
draw_hand "install_libltdl" "install libltdl ..."


# ld
ldconfig > /dev/null 2>>/root/error.log


# Wait for install packages background
draw_hand "install_packages_background" "wait while install packages background ..."

# sendmail
service sendmail restart > /dev/null 2>>/root/error.log
SET_SERVICE_STARTUP sendmail > /dev/null 2>>/root/error.log

# Install php
cd /tmp/pkit_dl_files
cd php-$php_ver
{
	./configure                                                \
	--prefix=/usr/local/php                                    \
	--with-mysql=/usr/local/mysql                              \
	--with-pdo-mysql=/usr/local/mysql/bin/mysql_config         \
	--with-mysqli=/usr/local/mysql/bin/mysql_config            \
	--enable-fpm                                               \
	--with-mcrypt=/usr/local/libmcrypt                         \
	--with-zlib --enable-mbstring                              \
	--with-openssl                                             \
	--with-gd                                                  \
	--with-jpeg-dir=/usr/lib                                   \
	--enable-gd-native-ttf                                     \
	--without-sqlite                                           \
	--with-gettext                                             \
	--with-curl                                                \
	--with-curlwrappers                                        \
	--enable-sockets                                           \
	--enable-bcmath                                            \
	--enable-xml                                               \
	--with-bz2                                                 \
	--with-gettext                                             \
	--enable-zip                                               \
	--enable-mbregex                                           \
	--with-config-file-path=/etc                               \
	--with-freetype-dir                                        \
	--with-jpeg-dir                                            \
	--with-png-dir                                             \
	--with-zlib                                                \
	--with-libxml-dir=/usr                                     \
	--disable-rpath                                            \
	--enable-safe-mode                                         \
	--enable-shmop                                             \
	--enable-sysvsem                                           \
	--enable-inline-optimization                               \
	--enable-mbstring                                          \
	--enable-gd-native-ttf                                     \
	--with-mhash                                               \
	--enable-pcntl                                             \
	--enable-sockets                                           \
	--with-xmlrpc                                              \
	--enable-soap                                              \
	--with-pear=/usr/local/php/pear                            \
	--without-pear                                             \
	--with-iconv=/usr/local/                                   \
	--enable-exif                                              \
	--enable-ftp                                               \
	--with-mime-magic                                          \
	--with-readline                                            \

	set_flag config_php
} > /dev/null 2>>/root/error.log &
draw_hand "config_php" "config php files for compile ..."
{
	make
	set_flag compile_php
} > /dev/null 2>>/root/error.log &
draw_hand "compile_php" "compile php ..."
{
	make install
	set_flag install_php
} > /dev/null 2>>/root/error.log &
draw_hand "install_php" "install php ..."

{
	cp -f ./php.ini-production /etc/php.ini
	cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf
	ln -s /usr/local/php/etc/php-fpm.conf /etc/php-fpm.conf
	mv ./sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
	chmod 755 /etc/init.d/php-fpm

	ln -s /usr/local/php/bin/php /usr/bin/php
	ln -s /usr/local/php/bin/phpize  /usr/bin/phpize
} > /dev/null 2>>/root/error.log


{
	sed -i 's#;pid = run/php-fpm.pid#pid = run/php-fpm.pid#' /usr/local/php/etc/php-fpm.conf
	sed -i 's#user = nobody#user = www#' /usr/local/php/etc/php-fpm.conf
	sed -i 's#group = nobody#group = www#' /usr/local/php/etc/php-fpm.conf
	sed -i 's#;pm.min_spare_servers = 5#pm.min_spare_servers = 5#' /usr/local/php/etc/php-fpm.conf
	sed -i 's#;pm.max_spare_servers = 35#pm.max_spare_servers = 35#' /usr/local/php/etc/php-fpm.conf
	sed -i 's#;pm.start_servers = 20#pm.start_servers = 20#' /usr/local/php/etc/php-fpm.conf
	sed -i 's#listen = 127.0.0.1:9000#listen = "/tmp/php-cgi.sock"#' /usr/local/php/etc/php-fpm.conf
} > /dev/null 2>>/root/error.log

# Install ImageMagick extension 
cd /tmp/pkit_dl_files
cd imagick-3.0.1
/usr/local/php/bin/phpize > /dev/null 2>>/root/error.log
{
	./configure --with-php-config=/usr/local/php/bin/php-config  --with-imagick=/usr/local/imagemagick 
	set_flag config_imagick
} > /dev/null 2>>/root/error.log &
draw_hand "config_imagick" "config imagick files for compile ..."


{
	make
	set_flag compile_imagick
} > /dev/null 2>>/root/error.log &
draw_hand "compile_imagick" "compile imagick ..."


{
	make install
	set_flag install_imagick
} > /dev/null 2>>/root/error.log &
draw_hand "install_imagick" "install imagick ..."



# Install memcached
cd /tmp/pkit_dl_files
cd memcached-$memcached_ver
{
	./configure
	set_flag config_memcached
} > /dev/null 2>>/root/error.log &
draw_hand "config_memcached" "config memcached files for compile ..."
{
	make
	set_flag compile_memcached
} > /dev/null 2>>/root/error.log &
draw_hand "compile_memcached" "compile memcached ..."
{
	make install
	set_flag install_memcached
} > /dev/null 2>>/root/error.log &
draw_hand "install_memcached" "install memcached ..."


# Install memcache
cd /tmp/pkit_dl_files
cd memcache-2.2.6
/usr/local/php/bin/phpize > /dev/null 2>>/root/error.log
{
	./configure --with-php-config=/usr/local/php/bin/php-config
	set_flag config_memcache
} > /dev/null 2>>/root/error.log &
draw_hand "config_memcache" "config memcache files for compile ..."
{
	make
	set_flag compile_memcache
} > /dev/null 2>>/root/error.log &
draw_hand "compile_memcache" "compile memcache ..."
{
	make install
	set_flag install_memcache
} > /dev/null 2>>/root/error.log &
draw_hand "install_memcache" "install memcache ..."

# Install ZendGuardLoader
cd /tmp/pkit_dl_files
if [ $ARCH = '32' ]
then
	cd ZendGuardLoader-php-5.3-linux-glibc23-i386
elif [ $ARCH = '64' ]
then
	cd ZendGuardLoader-php-5.3-linux-glibc23-x86_64
fi
cp -f php-5.3.x/ZendGuardLoader.so /usr/local/php/lib/php/extensions/no-debug-non-zts-20090626/
chown www:www /usr/local/php/lib/php/extensions/no-debug-non-zts-20090626/*

sed -i 's#; extension_dir = "./"#extension_dir = "/usr/local/php/lib/php/extensions/no-debug-non-zts-20090626/"\
extension = imagick.so\
extension = memcache.so#' /etc/php.ini
sed -i 's#short_open_tag = Off#short_open_tag = On#' /etc/php.ini
sed -i 's#;cgi.fix_pathinfo=1#cgi.fix_pathinfo=0#g' /etc/php.ini
sed -i 's#;cgi.fix_pathinfo=0#cgi.fix_pathinfo=0#g' /etc/php.ini
sed -i 's#upload_max_filesize = 2M#upload_max_filesize = 64M#g' /etc/php.ini
sed -i 's#post_max_size = 8M#post_max_size = 64M#g' /etc/php.ini
sed -i 's#;sendmail_path =#sendmail_path = sendmail -t -i#g' /etc/php.ini

SET_SERVICE_STARTUP php-fpm > /dev/null 2>>/root/error.log

#   +----------------------------------------------------------------------+
#   | Install Nginx                                                        |
#   +----------------------------------------------------------------------+

cd /tmp/pkit_dl_files
cd nginx-$ngx_ver

# Install Nginx
{
	./configure                            \
	--user=www                             \
	--group=www                            \
	--prefix=/usr/local/nginx              \
	--with-http_stub_status_module         \
	--with-http_ssl_module                 \
	
	set_flag config_nginx
} > /dev/null 2>>/root/error.log &
draw_hand "config_nginx" "config nginx files for compile ..."
{
	make
	set_flag compile_nginx
} > /dev/null 2>>/root/error.log &
draw_hand "compile_nginx" "compile nginx ..."
{
	make install
	set_flag install_nginx
} > /dev/null 2>>/root/error.log &
draw_hand "install_nginx" "install nginx ..."

cd /tmp/pkit_dl_files
mv nginx.init.$os /etc/init.d/nginx
chmod 755 /etc/init.d/nginx
chown -R www:www /home/www/

mkdir /usr/local/nginx/conf/vhost/
ln -s /usr/local/nginx/conf/vhost/ /root/vhost

cp nginx.conf -f /usr/local/nginx/conf/

{
	service nginx start
	set_flag start_nginx_service
} > /dev/null 2>>/root/error.log &
draw_hand "start_nginx_service" "start nginx service ..."

SET_SERVICE_STARTUP nginx > /dev/null 2>>/root/error.log

#   +----------------------------------------------------------------------+
#   | Finish                                                               |
#   +----------------------------------------------------------------------+

cat >>/root/setup.txt<<EOF
========== MySQL =============
user    : root
password: $myrootpwd
=============================

Support site: 
http://pkit.org
EOF

rm -rf /tmp/pkit_dl_files
rm /tmp/lnmp.sh
cd
mv screenlog.0 screen.log

exit