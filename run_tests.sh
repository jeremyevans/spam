#!/bin/sh
WAITTIME=5
echo -n '' > log/test.log
style -c config/style.test.yaml start
sleep $WAITTIME
ruby test.rb
style -c config/style.test.yaml stop
