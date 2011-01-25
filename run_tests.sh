#!/bin/sh
WAITTIME=5
if [ X"$BUNDLE" == "X" ]; then
  BUNDLE=bundle
fi
if [ X"$UNICORN" == "X" ]; then
  UNICORN=unicorn
fi
if [ X"$RUBY" == "X" ]; then
  SPEC=spec
fi
echo -n '' > log/test.log
echo -n '' > /var/www/logs/unicorn/spam.test.log
$BUNDLE exec $UNICORN -c config/unicorn.test.conf -D
sleep $WAITTIME
$SPEC test.rb
kill `cat /var/www/tmp/spam.test.pid`
