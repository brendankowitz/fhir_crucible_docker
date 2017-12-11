#!/bin/bash

cd /home/app/crucible
RAILS_ENV=production rake assets:precompile

su root -c 'export PATH=$PATH:/usr/local/bin/ruby ; RAILS_ENV=production /home/app/crucible/bin/delayed_job -n3 start'

/sbin/my_init
