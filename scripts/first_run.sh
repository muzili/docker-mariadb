USER=${USER:-admin}
PASS=${PASS:-$(pwgen -s -1 16)}
DB_USER=${DB_USER:-demo}
DB_PASS=${DB_PASS:-$(pwgen -s -1 16)}
DB_NAME=${DB_NAME:-demodb}

pre_start_action() {
    # Echo out info to later obtain by running `docker logs container_name`
    echo "Super user: $USER"
    echo "Super pass: $PASS"
    echo "MARIADB_USER=$DB_USER"
    echo "MARIADB_PASS=$DB_PASS"
    echo "MARIADB_NAME=$DB_NAME"
    echo "MARIADB_DATA_DIR=$DATA_DIR"

    # Create a directory for the source code.
    mkdir -p -m 700 /var/log/mysql
    mkdir -p -m 700 /var/lib/mysql
    chown mysql -R /var/lib/mysql /var/log/mysql

    # fix permissions and ownership of /run/mysqld
    mkdir -p -m 0755 /run/mysqld
    chown -R mysql:root /run/mysqld

    # Set up restrict mode for phabricator
    sed -i -e 's/bind-address.*$/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
    cat /etc/mysql/my.cnf | grep -v '^#'

    echo "=> Installing MariaDB ..."
    mysql_install_db --user=mysql
    echo "=> Done!"

    /usr/bin/mysqld_safe > /dev/null 2>&1 &

    mysqladmin --silent --wait=36 ping || exit 1

    # Create the superuser.
    mysql -u root <<-EOF
      DELETE FROM mysql.user WHERE user = '$USER';
      FLUSH PRIVILEGES;
      CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASS';
      GRANT ALL PRIVILEGES ON *.* TO '$USER'@'localhost' WITH GRANT OPTION;
      CREATE USER '$USER'@'%' IDENTIFIED BY '$PASS';
      GRANT ALL PRIVILEGES ON *.* TO '$USER'@'%' WITH GRANT OPTION;
EOF

    #
    # the default password for the debian-sys-maint user is randomly generated
    # during the installation of the mysql-server package.
    #
    # Due to the nature of docker we blank out the password such that the maintenance
    # user can login without a password.
    #
    sed 's/password = .*/password = /g' -i /etc/mysql/debian.cnf
    mysql -u root -e \
          "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '';"

    if [ -n "${DB_NAME}" ]; then
        for db in $(awk -F',' '{for (i = 1 ; i <= NF ; i++) print $i}' <<< "${DB_NAME}"); do
            echo "Creating database \"$db\"..."
            mysql -u root  \
                  -e "CREATE DATABASE IF NOT EXISTS \`$db\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;"
            if [ -n "${DB_USER}" ]; then
                echo "Granting access to database \"$db\" for user \"${DB_USER}\"..."
                mysql -u root \
                      -e "GRANT ALL PRIVILEGES ON \`$db\`.* TO '${DB_USER}' IDENTIFIED BY '${DB_PASS}';"
            fi
        done
    fi

    echo "=> Done!"

    echo "========================================================================"
    echo "You can now connect to this MariaDB Server using:"
    echo ""
    echo "    mysql -u$DB_USER -p$DB_PASS -h<host> -P<port>"
    echo ""
    echo "Please remember to change the above password as soon as possible!"
    echo "MariaDB user 'root' has no password but only allows local connections"
    echo "========================================================================"

    mysqladmin -uroot shutdown
}

post_start_action() {
    rm /firstrun
}
