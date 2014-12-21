USER=${USER:-admin}
PASS=${PASS:-$(pwgen -s -1 16)}

pre_start_action() {
  # Echo out info to later obtain by running `docker logs container_name`
  echo "MARIADB_USER=$USER"
  echo "MARIADB_PASS=$PASS"
  echo "MARIADB_DATA_DIR=$DATA_DIR"

  echo "=> Installing MariaDB ..."
  mysql_install_db > /dev/null 2>&1
  echo "=> Done!"

  /usr/bin/mysqld_safe > /dev/null 2>&1 &

  RET=1
  while [[ RET -ne 0 ]]; do
      echo "=> Waiting for confirmation of MariaDB service startup"
      sleep 5
      mysql -uroot -e "status" > /dev/null 2>&1
      RET=$?
  done

    # Create the superuser.
  mysql -u root <<-EOF
      DELETE FROM mysql.user WHERE user = '$USER';
      FLUSH PRIVILEGES;
      CREATE USER '$USER'@'localhost' IDENTIFIED BY '$PASS';
      GRANT ALL PRIVILEGES ON *.* TO '$USER'@'localhost' WITH GRANT OPTION;
      CREATE USER '$USER'@'%' IDENTIFIED BY '$PASS';
      GRANT ALL PRIVILEGES ON *.* TO '$USER'@'%' WITH GRANT OPTION;
EOF

  # The password for 'debian-sys-maint'@'localhost' is auto generated.
  # The database inside of DATA_DIR may not have been generated with this password.
  # So, we need to set this for our database to be portable.
  # And mysql require the account to shutdown
  DB_MAINT_PASS=$(cat /etc/mysql/debian.cnf | grep -m 1 "password\s*=\s*"| sed 's/^password\s*=\s*//')
  mysql -u root -e \
        "GRANT ALL PRIVILEGES ON *.* TO 'debian-sys-maint'@'localhost' IDENTIFIED BY '$DB_MAINT_PASS';"

  # Set up restrict mode for phabricator
  sed -i -e's/^#*sql_mode.*/sql_mode\t= STRICT_ALL_TABLES\nft_min_word_len\t= 3/g' /etc/mysql/my.cnf
  echo "=> Done!"

  echo "========================================================================"
  echo "You can now connect to this MariaDB Server using:"
  echo ""
  echo "    mysql -u$USER -p$PASS -h<host> -P<port>"
  echo ""
  echo "Please remember to change the above password as soon as possible!"
  echo "MariaDB user 'root' has no password but only allows local connections"
  echo "========================================================================"

  mysqladmin -uroot shutdown
}

post_start_action() {
  rm /firstrun
}
