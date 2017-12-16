#!/bin/bash

su root -c 'mongod --fork --syslog'
su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production /home/app/crucible/bin/delayed_job -n3 start'

/sbin/my_init
