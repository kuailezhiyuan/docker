#!/bin/sh
echo ""
echo "Starting Docker-Linux ... "
echo ""
echo "[$(date "+%G/%m/%d %H:%M:%S")] Initalizing MySQL Database ..." 

echo "[$(date "+%G/%m/%d %H:%M:%S")] Checking MySQL socket ..."
if [ -d "/run/mysqld" ]; then
	echo "[$(date "+%G/%m/%d %H:%M:%S")] /run/mysqld already present !"
    echo "[$(date "+%G/%m/%d %H:%M:%S")] Changing privilege for /run/mysqld ..."
	chown -R mysql:mysql /run/mysqld
else
	echo "[$(date "+%G/%m/%d %H:%M:%S")] /run/mysqld not found, creating...."
	mkdir -p /run/mysqld
    echo "[$(date "+%G/%m/%d %H:%M:%S")] Changing privilege for /run/mysqld ..."
	chown -R mysql:mysql /run/mysqld
fi

echo "[$(date "+%G/%m/%d %H:%M:%S")] Checking MySQL directory ..." 
if [ -d "/var/lib/mysql/mysql" ]; then
	echo "[$(date "+%G/%m/%d %H:%M:%S")] MySQL directory already present !"
    echo "[$(date "+%G/%m/%d %H:%M:%S")] Changing privilege for /var/lib/mysql ..."
	chown -R mysql:mysql /var/lib/mysql
else
    echo "[$(date "+%G/%m/%d %H:%M:%S")] MySQL data directory not found !"
    echo "[$(date "+%G/%m/%d %H:%M:%S")] Changing privilege for /var/lib/mysql ..."
	chown -R mysql:mysql /var/lib/mysql
    echo "[$(date "+%G/%m/%d %H:%M:%S")] MySQL data directory not found, creating initial database ..."
    echo "[$(date "+%G/%m/%d %H:%M:%S")] Please wait, this may take a while ..."
	mysql_install_db --user=mysql >/dev/null 2>&1
	
	# MySQL ROOT Password
	echo "[$(date "+%G/%m/%d %H:%M:%S")] Checking MySQL Root Password ..." 
	if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Not finding any paramters about MySQL Root Password !"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generating MySQL Root Password ..."
		MYSQL_ROOT_PASSWORD="$(pwgen 16 1)"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generate Success !"
		echo "[$(date "+%G/%m/%d %H:%M:%S")] MySQL root Password is : $MYSQL_ROOT_PASSWORD"
	else
	    echo "[$(date "+%G/%m/%d %H:%M:%S")] Existing MySQL Root Password found : $MYSQL_ROOT_PASSWORD"
	fi

    # MySQL Database Name
	echo "[$(date "+%G/%m/%d %H:%M:%S")] Checking MySQL Database Name ..." 
	if [ "$MYSQL_DATABASE" = "" ]; then
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Not finding any paramters about MySQL Database !"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generating MySQL Database Name ..."
		MYSQL_DATABASE="cloudreve_db_$(pwgen 8 1)"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generate Success !"
		echo "[$(date "+%G/%m/%d %H:%M:%S")] MySQL Database name is : $MYSQL_DATABASE"
	else
	    MYSQL_DATABASE=${MYSQL_DATABASE:-""}
	    echo "[$(date "+%G/%m/%d %H:%M:%S")] Existing MySQL Database Name found : $MYSQL_DATABASE"
	fi

    # MySQL Username
	echo "[$(date "+%G/%m/%d %H:%M:%S")] Checking MySQL Username ..." 
	if [ "$MYSQL_USER" = "" ]; then
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Not finding any paramters about MySQL Username !"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generating MySQL Username ..."
		MYSQL_USER="cloudreve_user_$(pwgen 8 1)"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generate Success !"
		echo "[$(date "+%G/%m/%d %H:%M:%S")] MySQL Username is : $MYSQL_USER"
	else
	    MYSQL_USER=${MYSQL_USER:-""}
	    echo "[$(date "+%G/%m/%d %H:%M:%S")] Existing MySQL Username found : $MYSQL_USER"
	fi

	# MySQL User Password
	echo "[$(date "+%G/%m/%d %H:%M:%S")] Checking MySQL User Password ..." 
	if [ "$MYSQL_PASSWORD" = "" ]; then
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Not finding any paramters about User Password !"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generating MySQL User Password ..."
		MYSQL_PASSWORD="$(pwgen 16 1)"
        echo "[$(date "+%G/%m/%d %H:%M:%S")] Generate Success !"
		echo "[$(date "+%G/%m/%d %H:%M:%S")] MySQL User Password is : $MYSQL_PASSWORD"
	else
	    MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}
	    echo "[$(date "+%G/%m/%d %H:%M:%S")] Existing MySQL User Password found : $MYSQL_PASSWORD"
	fi

echo "[$(date "+%G/%m/%d %H:%M:%S")] Initializing MySQL Database ..." 

	tfile=`mktemp`
	if [ ! -f "$tfile" ]; then
	    return 1
	fi

	cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION;
UPDATE user SET password=PASSWORD("$MYSQL_ROOT_PASSWORD") WHERE user='root' AND host='localhost';
EOF

	if [ "$MYSQL_DATABASE" != "" ]; then
	    echo "[$(date "+%G/%m/%d %H:%M:%S")] Creating database: $MYSQL_DATABASE"
	    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile
	    if [ "$MYSQL_USER" != "" ]; then
		echo "[$(date "+%G/%m/%d %H:%M:%S")] Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"
		echo "grant all privileges on $MYSQL_DATABASE.* to $MYSQL_USER@localhost identified by '$MYSQL_PASSWORD';" >> $tfile
		echo "FLUSH PRIVILEGES;" >> $tfile
	    fi
	fi
	echo "[$(date "+%G/%m/%d %H:%M:%S")] Initializing MySQL ..." 
	/usr/bin/mysqld --user=mysql --bootstrap --verbose=0 < $tfile >/dev/null 2>&1
	rm -f $tfile
fi

echo "[$(date "+%G/%m/%d %H:%M:%S")] Starting MariaDB (MySQL) in deamon mode ..."
exec nohup /usr/bin/mysqld_safe --user=mysql >/dev/null 2>&1 &
echo "[$(date "+%G/%m/%d %H:%M:%S")] Preparing installation of Cloudreve ..."
echo "[$(date "+%G/%m/%d %H:%M:%S")] Installing Cloudreve (hfo4/cloudreve) ..." 
cd /
echo "y" >> cloudreve_set
echo "$MYSQL_URL" >> cloudreve_set
echo "$MYSQL_DATABASE" >> cloudreve_set
echo "$MYSQL_USER" >> cloudreve_set
echo "$MYSQL_PASSWORD" >> cloudreve_set
echo "$MYSQL_PORT" >> cloudreve_set
echo "$CLOUDREVE_URL" >> cloudreve_set
composer config -g repo.packagist composer https://packagist.phpcomposer.com
composer create-project hfo4/cloudreve:dev-master < cloudreve_set
chown -R apache:apache /cloudreve
rm -f cloudreve_set
cd /cloudreve
echo "[$(date "+%G/%m/%d %H:%M:%S")] Installing Plugin : Google 2FA Autchenticator (phpgangsta/googleauthenticator) ..."
composer require phpgangsta/googleauthenticator:dev-master
echo "[$(date "+%G/%m/%d %H:%M:%S")] Installing Plugin : QR Code (endroid/qrcode)  ..."
composer require endroid/qr-code
echo "[$(date "+%G/%m/%d %H:%M:%S")] Finished installation of Cloudreve "
echo ""
echo "[$(date "+%G/%m/%d %H:%M:%S")] Finishing Deployment ..."
echo ""
echo " --- Information of the running enviroment --- "
echo ""
echo " Linux Version : Alpine Linux $(cat /etc/alpine-release)"
echo " Linux Kernel Version : $(uname -r)"
echo " Linux Architecture : $(uname -m)"
echo " Docker Hostname : $(uname -n)"
echo " Server IP : $(curl -s whatismyip.akamai.com)"
echo ""
#echo " Linux ROOT User Password : $ROOT_PASSWORD "
echo " MySQL ROOT User Password : $MYSQL_ROOT_PASSWORD "
echo " MySQL Database Name : $MYSQL_DATABASE "
echo " MySQL Username : $MYSQL_USER "
echo " MySQL Password : $MYSQL_PASSWORD "
echo ""
echo " Cloudreve Installation Path : /cloudreve "
echo " Cloudreve URL : $CLOUDREVE_URL "
echo " Cloudreve Admin Panel URL : ${CLOUDREVE_URL}Admin "
echo " Cloudreve default username : admin@cloudreve.org "
echo " Cloudreve default password : admin "
echo " "
echo "***********************************************"
echo ""
echo "[$(date "+%G/%m/%d %H:%M:%S")] Starting Apache ... "
echo "[$(date "+%G/%m/%d %H:%M:%S")] Start Success ! Enjoy your Docker-Cloudreve ! "
echo ""
echo "***********************************************"
echo ""
echo "本镜像由 ilemonrain <ilemonrain@ilemonrain.com> 制作"
echo "Docker镜像名称：ilemonrain/cloudreve"
echo "Docker Hub地址：https://hub.docker.com/r/ilemonrain/cloudreve/"
echo "镜像部署文档：https://blog.ilemonrain.com/docker/cloudreve.html"
echo "请在保留作者信息的前提下，欢迎使用及转载镜像"
echo ""
echo "This Docker Image is made by ilemonrain <ilemonrain@ilemonrain.com>"
echo "Docker Image : ilemonrain/cloudreve"
echo "Docker Hub : https://hub.docker.com/r/ilemonrain/cloudreve/"
echo "Tutorial : https://blog.ilemonrain.com/docker/cloudreve.html"
echo "You can use the image with the CC BY-NC-SA 3.0 agreement."
echo ""
echo "***********************************************"
echo ""
httpd -D FOREGROUND
echo "[$(date "+%G/%m/%d %H:%M:%S")] Apache 2 is stopped ..."
echo "[$(date "+%G/%m/%d %H:%M:%S")] Shutting down Docker Linux ..."
echo "[$(date "+%G/%m/%d %H:%M:%S")] If this was happened unnormally, please contact author with bug report !"
