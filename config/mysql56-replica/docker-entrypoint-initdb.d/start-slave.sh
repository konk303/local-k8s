#!/bin/sh

# Copied from https://qiita.com/takyam/items/f13bc4a1db0433ffb958

# depends_onの設定しておけば気にならないけど念の為masterの起動を待つ
while ! mysqladmin ping -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} --silent; do
  sleep 1
done

# masterをロックする
mysql -u root -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} -e "RESET MASTER;"
mysql -u root -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} -e "FLUSH TABLES WITH READ LOCK;"

# masterのDB情報をDumpする
# ここでは --all-databases にしてるけど用途に応じて必要なDBだけにしていいと思う
mysqldump -uroot -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} --all-databases --master-data --single-transaction --flush-logs --events > /tmp/master_dump.sql
# 特定のDBだけにする場合はこんな感じ(my.cnfのreplica-do-dbも忘れずに設定すること)
# mysqldump -uroot -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} データベース名 --master-data --single-transaction --flush-logs --events > /tmp/master_dump.sql

# dumpしたmasterのDBをslaveにimportする
mysql -u root -e "STOP SLAVE;";
mysql -u root < /tmp/master_dump.sql

# masterに繋いで bin-logのファイル名とポジションを取得する
log_file=`mysql -u root -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} -e "SHOW MASTER STATUS\G" | grep File: | awk '{print $2}'`
pos=`mysql -u root -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} -e "SHOW MASTER STATUS\G" | grep Position: | awk '{print $2}'`

# slaveの開始
mysql -u root -e "RESET SLAVE";
mysql -u root -e "CHANGE MASTER TO MASTER_HOST='${MYSQL56_PRIMARY_SVC_SERVICE_HOST}', MASTER_PORT=${MYSQL56_PRIMARY_SVC_SERVICE_PORT}, MASTER_USER='root', MASTER_PASSWORD='', MASTER_LOG_FILE='${log_file}', MASTER_LOG_POS=${pos};"
mysql -u root -e "start slave"

# masterをunlockする
mysql -u root -h ${MYSQL56_PRIMARY_SVC_SERVICE_HOST} -P ${MYSQL56_PRIMARY_SVC_SERVICE_PORT} -e "UNLOCK TABLES;"
