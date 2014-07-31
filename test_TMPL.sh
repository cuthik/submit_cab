#!/bin/bash

##
## @file test_TMPL.sh
##
## Description of the script file
##
## @author cuto <Jakub.Cuth@cern.ch>
## @date 2014-05-07


#PBS -N test_dspace
# #PBS -j oe
#PBS -k oe
#PBS -q sam_hi@d0cabsrv2
#PBS -l nodes=1


DRY_RUN="echo "
DRY_RUN=""

# testing space
pwd
ls -l

# WORK PLACE
WORKAREA=/scratch/${PBS_JOBID}
cd $WORKAREA

pwd

echo -n "======= starting resbos: "; date

exit 0

# testing the uploading

upload_to_SAM(){
    # first is tar name
    file=$1
    tar_def=$*
    filebase=`basename $file .tar`
    meta=$file.metadata.py
    # setup SAM
    setup sam -q cabsrv1
    # tar file and make description
    rm -f $file
    tar cvf $tar_def
    echo "
from SamFile.SamDataFile import  *

TheFile = NonPhysicsGenericFile({
          'fileName' : '$filebase.tar',
          'fileType' : 'nonPhysicsGeneric',
          'fileSize' : SamSize('`stat -c %sB $filebase.tar`'),
 'fileContentStatus' : 'good',
             'group' : 'dzero',
})
" > $meta
    # make SAM store request
    echo storing to sam a file: $file
    $DRY_RUN sam store -v --station=fnal-cabsrv2 --sourceFile=$file --descriptionFile=$meta --waitForCompletion
    # define project (tar name without )
    echo creating new definition: $filebase
    $DRY_RUN sam create definition --dim="file_name $filebase.tar" --defname="$filebase" --group=dzero
    # wait until transfer finished
    # locate file
}


link_file_SAM(){
    project_name=$1
    echo "
#!/usr/bin/env python
#
# This file sets up and runs a SAM project.
#
import os, sys, string, time, signal
from re import *
#from globals import *
#import run_project

############################################################################
#
#  Set the following variables to appropriate values

# Consult database for valid choices
#sam_station        = 'fnal-cabsrv1'
sam_station        = os.environ['SAM_STATION']


# Consult Database for valid choices
project_definition = '$project_name'

# A particular snapshot version, last or new
snapshot_version   = 'new'

# Consult database for valid choices
appname            = 'generic'
version            = '1'
group              = 'dzero'


# The maximum number of files to get from sam
max_file_amt       = 10000

# for additional debug info use '--verbose'
verbosity          = '--verbose'
#verbosity           = ''

# Give up on all exceptions
give_up            = 1


def file_ready(filename):
    # Replace this python subroutine with whatever you want to do
    # to process the file that was retrieved.
    # Your program will only be called in the event of
    # a successful delivery.
    #

    print 'Create local link'
    print filename
    os.system('ln -s %s  .; sleep 1 &'%filename)
    time.sleep(1)
    return
    " > get_file.py
    sam run project --group=dzero --project="${project_name}_`date +%s`" --interactive get_file.py
    tar xvf $project_name.tar
}

#WORKAREA=/scratch/${PBS_JOBID}
#cd $WORKAREA

#echo " +++ gets the environment "
#source /usr/products/etc/setups.sh


#setup setpath
#setup limit_transfers
#setup sam -q cabsrv1

#pwd

# Test of new functions
cp /prj_root/7056/wmass2/jcuth/clued0out_respmcs/tupleMaker_high_NS_1234568.log testlog.txt
upload_to_SAM jcuth_test_`date +%s`.tar testlog.txt

#link_file jcuth_test_1400557472

ls -la


ls -la /rooms/wmass/hengne/TBLibrary
ls -la /rooms/wmass/rclsa/DATA/MBZBLibrary
ls -la /rooms/wmass/rclsa/DATA/MBZBLibrary
ls -la /rooms/wmass/jenny/MC/HRLibrary


exit 0
