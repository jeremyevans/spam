#!/bin/sh
WAITTIME=5
echo -n '' > log/test.log
echo -n '' > /var/www/logs/unicorn/spam.test.log
bundle exec unicorn -c config/unicorn.test.conf -D
sleep $WAITTIME
ruby test.rb
kill `cat /var/www/tmp/spam.test.pid`
