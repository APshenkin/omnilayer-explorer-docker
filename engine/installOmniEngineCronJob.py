#
# Install OmniEngine as a Cron Job for the current user
#
# Script is written for Linux/Unix, tested on Ubuntu
# Requires the python-crontab package.
#
import os
from crontab import CronTab

#
# Setup the cron command to run from the current user's omniEngine directory.
#
homeDir=os.environ['HOME']
network=os.environ['NETWORK']
engineCommand='NETWORK={1} python {0}/omniEngine/omniEngine.py >> /proc/1/fd/1'.format(homeDir, network)
engineComment='Update OmniEngne DB using RPC'

#
# Access the current users' CronTab
#
cron = CronTab(user=True)

# Look for existing job
found = cron.find_command('omniEngine.py')
job = next(found,None)
if job is not None:
    # If existing job, clear all fields and set correct values
    print "Found existing job: "
    print job
    job.clear()
    job.set_command(engineCommand)
    job.set_comment(engineComment)
else:
    # If no existing job, set up job from scratch
    print "Adding job."
    job = cron.new(command=engineCommand,comment='load Tx into DB using RPC')
job.minute.every(1)
print "Writing job:"
print job
# Update user's crontab file
cron.write()
