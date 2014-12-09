#!/bin/sh

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi

echo "==========================="

	fetch_location="US"
	echo "Please choose the location to fetch files(US/CN):"
	read -p "(Default US, if you want to fetch from china node please input: CN , if NOT please press the enter button):" fetch_location

	case "$fetch_location" in
	cn|CN|cN|Cn)
	echo "You will fetch files from CN!"
	fetch_location="CN"
	;;
	us|Us|uS|US)
	echo "You will fetch files from US!"
	fetch_location="US"
	;;
	*)
	echo "INPUT ERROR, you will fetch files from US!"
	fetch_location="US"
	esac

export fetch_location

# 这个脚本只做基本的前置处理和善后操作。
# 1) 安装 screen
# 2) 判断系统
# 3) 通过screen执行安装脚本，安装后退出screen。
# 4) 打印信息

#   +----------------------------------------------------------------------+
#   | Functions                                                            |
#   +----------------------------------------------------------------------+

# 
# $1 path_to_flag_file
# $2 message_to_print
# flag_pre /tmp/_lnmp_flag_
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

for release in centos debian
do
	if grep -i $release /etc/issue> /dev/null 2>&1
	then
		os=$release
		break
	fi
done
export os

msg='detect os type ...'
x_msg "$os" "$msg"


case $os in
centos)
	INSTALL_PACKAGE='yum install -y -q'

	PACKAGE_F='
		unzip wget
		gcc gcc-c++ cmake make 
		libtool-ltdl libtool-ltdl-devel
		glibc glibc-devel
		glib2 glib2-devel
		ncurses ncurses-devel
		bison
		zlib zlib-devel
		libtool
		file 
	'
	
	PACKAGE_B='
		libevent libevent-devel
		sendmail 
		libxml2 libxml2-devel
		openssl openssl-devel
		curl curl-devel
		bzip2 bzip2-devel
		libjpeg libjpeg-devel
		libpng libpng-devel
		freetype freetype-devel
		pcre pcre-devel
		libmcrypt libmcrypt-devel
		mhash mhash-devel
		ImageMagick ImageMagick-devel
		tcp_wrappers-devel tcp_wrappers
		redhat-lsb
		readline readline-devel
	'
	;;
	
debian | ubuntu)
	{
		apt-get update
		set_flag apt_get_update
	} > /dev/null 2>&1 &
	MSG="apt-get update ..."
	draw_hand "apt_get_update" "$MSG"
	
	INSTALL_PACKAGE='apt-get install -y  --force-yes'

	PACKAGE_F='
		wget
		unzip
		gcc 
		g++ 
		make
		autoconf
		automake
		flex
		bison 
		libtool 
		cmake 
		libncurses5 libncurses5-dev
		zlib1g zlib1g-dev
		file
	'
	PACKAGE_B='
		mcrypt sendmail
		curl libcurl3 libcurl4-openssl-dev 
		libjpeg-dev 
		libpng-dev libpng12-0 libpng12-dev libpng3 libpng12-dev 
		libxml2 libxml2-dev 
		libfreetype6 libfreetype6-dev 
		libjpeg62 libjpeg62-dev libjpeg-dev 
		bzip2
		libbz2-dev 
		libzip-dev 
		libevent-dev
		imagemagick
		libmagick++-dev 
		libpcre3 libpcre3-dev	
		libreadline6 libreadline6-dev
		libwrap0-dev libwrap0
	'
	;;
esac

export INSTALL_PACKAGE
export PACKAGE_F
export PACKAGE_B
{
	$INSTALL_PACKAGE screen
	set_flag install_screen
}> /dev/null 2>&1 &
MSG="installing screen ..."
draw_hand "install_screen" "$MSG"

{
	wget -q http://pkit.org/step2.sh -O /tmp/step2.sh
	chmod 755 /tmp/step2.sh
	set_flag download_script
}> /dev/null 2>&1 &
MSG="downloading install script ..."
draw_hand "download_script" "$MSG"

echo "Ready for Installation"
sleep 3

screen -h 10240 -L -t 'Now Installing LNMP...   Suport Site: pkit.org' /tmp/step2.sh

clear

echo LNMP install finished. 
cat /root/setup.txt

printf \\a
sleep 1
printf \\a
sleep 1
printf \\a