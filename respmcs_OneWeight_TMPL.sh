#!/bin/bash

##
## @file respmcs_OneWeight_TMPL.sh
##
## Control script for running chain -- resbos and pmcs.
## EDITWARNING
##
## @author cuto <Jakub.Cuth@cern.ch>
## @date 2014-03-17

#PBS -N respmcs_SAMPLENAME_RANDOMSEED
#PBS -q sam_lo@d0cabsrv2
#  #PBS -j oe
#PBS -k oe
#PBS -o /prj_root/7056/wmass2/jcuth/cabout_logs/
#PBS -e /prj_root/7056/wmass2/jcuth/cabout_logs/
#PBS -l nodes=1

resbosintface=/prj_root/7055/wmass2/jcuth/epmcs_analysis/resbosa_interface
outdir=/prj_root/7056/wmass2/jcuth/cabout_respmcs
#intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateBIG.in
intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateBIGhalf.in

#intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateSMALL.in

#RESBOS DIR
pmcsdir=/prj_root/7055/wmass2/jcuth/epmcs_analysis/wz_epmcs
pmcssrc=$pmcsdir/src

# for testing the settings
dryrun="echo "
# !!!! uncomment line below to actualy run something !!! 
dryrun=

CP="${dryrun}ln -sf "
CP="${dryrun}cp "
CP="${dryrun}rsync -rLvzu "

Run_resbos(){
    # setup env
    if [[ `uname -p` == "x86_64" ]]
    then
        echo 64bit | tee resbos.log
        setup root v5_26_00d -q GCC_4_5_1 -f Linux64bit+2.6-2.5
        setup cern 2004 -q x86_64
        resbosrootdir=$resbosintface/resbos_CP_020811_64
    else
        echo 32bit | tee resbos.log
        setup root v5_18_00_lts3-32_py243_dzero -q gcc343:opt
        resbosrootdir=$resbosintface/resbos_CP_020811
    fi


    # get all files
    wgt=-2
    if [[ MAIN == *CENTRAL* ]]
    then
        wgt=-1
    else
        if [[ SAMPLENAME == *local* ]];
        then
            $CP $outdir/weight_`echo CENTRAL| sed "s|\.||g"`_RANDOMSEED.dat .
        else
            get_file_SAM jcuth_resbos_CENTRAL_RANDOMSEED_weight
        fi | tee -a resbos.log

        ln -s weight_CENTRAL_RANDOMSEED.dat weights.dat
    fi
    ${dryrun}cat $intemplate | sed "s|1234567|RANDOMSEED|g;s|IWGT|$wgt|g" > resbos.in
    $CP MAIN main.out
    $CP YK yk.out
    $CP $resbosrootdir/resbos resbos


    #run
    ls -l | tee -a resbos.log
    $dryrun ./resbos | tee -a resbos.log

    #save 
    if [[ MAIN == *CENTRAL* ]]
    then
        if [[ SAMPLENAME == *local* ]];
        then
            # put on group disk
            $CP weights.dat $outdir/weight_SAMPLENAME_RANDOMSEED.dat
            $CP resbos.hep  $outdir/resbos_SAMPLENAME_RANDOMSEED.hep
        else
            # put on group disk
            $CP weights.dat $outdir/weight_SAMPLENAME_RANDOMSEED.dat
            $CP resbos.hep  $outdir/resbos_SAMPLENAME_RANDOMSEED.hep

            # upload to SAM
            ssh d0mino04 " cd $outdir; ./upload_to_SAM.sh jcuth_resbos_CENTRAL_RANDOMSEED_weight weight_SAMPLENAME_RANDOMSEED.dat"
            ssh d0mino04 " cd $outdir; ./upload_to_SAM.sh jcuth_resbos_CENTRAL_RANDOMSEED_hep    resbos_SAMPLENAME_RANDOMSEED.hep"

            # remove from group disk
            rm $outdir/weight_SAMPLENAME_RANDOMSEED.dat*
            rm $outdir/resbos_SAMPLENAME_RANDOMSEED.hep*
        fi
    fi | tee -a resbos.log
    $CP resbos.log $outdir/resbos_SAMPLENAME_RANDOMSEED.log

}

get_file_SAM(){
    project_name=$1
    download_project=${project_name}_SAMPLENAME_down`date +%s`
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
    " > get_file_$download_project.py
    sam run project --group=dzero --project="$download_project" --interactive get_file_$download_project.py
}

upload_to_SAM(){
    # first is tar name
    definition=$1
    filepath=$2
    file=`basename $filepath`

    # make SAM store request for each file
    meta=$file.metadata.py
    echo "
from SamFile.SamDataFile import  *

TheFile = NonPhysicsGenericFile({
          'fileName' : '$file',
          'fileType' : 'nonPhysicsGeneric',
          'fileSize' : SamSize('`stat -c %sB $filepath`'),
 'fileContentStatus' : 'good',
             'group' : 'dzero',
})
" > $meta
    echo storing to sam a file: $filepath
    $DRY_RUN sam store file -v --station=fnal-cabsrv2 --sourceFile=$filepath --descriptionFile=$meta --waitForCompletion


    # define project (tar name without )
    echo creating new definition: $definition
    $DRY_RUN sam create definition --dim="file_name $file" --defname="$definition" --group=dzero
}

Run_tuple_maker(){
    # setup env
    setup D0RunII p21.26.00 -O SRT_QUAL=maxopt

    # get all files
    mv weights.txt weight_SAMPLENAME_RANDOMSEED.txt
    if [[ MAIN == *CENTRAL* ]]
    then
        echo "Tuple maker shout not be run for central sample"
    else
        if [[ SAMPLENAME == *local* ]]
        then
            ln -sf $outdir/resbos_CENTRAL_local_RANDOMSEED.hep resbos_CENTRAL_RANDOMSEED.hep
        else
            get_file_SAM jcuth_resbos_CENTRAL_RANDOMSEED_hep 
        fi
    fi | tee tupleMaker.log
    $CP $resbosintface/tupleMaker/tupleMaker2 .
    $CP $resbosintface/tupleMaker/get_entries.C get_entries.C

    # run
    ls -l | tee -a tupleMaker.log
    ./tupleMaker2 CENTRAL RANDOMSEED SAMPLENAME | tee -a tupleMaker.log
    echo -n "======= get entries: "; date
    root -l -b -q resbos_SAMPLENAME_RANDOMSEED.root get_entries.C | tee -a tupleMaker.log

    # save
    $CP tupleMaker.log $outdir/tupleMaker_SAMPLENAME_RANDOMSEED.log
}

Run_pmcs(){
    # setup env
    setup lhapdf
    #export TBLibraryRootPath="/rooms/wmass/hengne/TBLibrary"
    #export MBLibraryRootPath="/rooms/wmass/rclsa/DATA/MBZBLibrary"
    #export ZBLibraryRootPath="/rooms/wmass/rclsa/DATA/MBZBLibrary"
    #export HRLibraryRootPath="/rooms/wmass/jenny/MC/HRLibrary"
    export TBLibraryRootPath="./"
    export MBLibraryRootPath="./"
    export ZBLibraryRootPath="./"
    export HRLibraryRootPath="./"

    # get all files
    # cp executable instead of compilation
    #$CP $pmcssrc/run_pmcs .
    #$CP $pmcssrc/parameters.rc .
    $CP /prj_root/7055/wmass2/jcuth/epmcs_newTrigger/wz_epmcs/src/run_pmcs .
    $CP /prj_root/7055/wmass2/jcuth/epmcs_newTrigger/wz_epmcs/src/parameters.rc .

    ls resbos_SAMPLENAME_RANDOMSEED*.root > file.list
    echo "=== file.list ==="
    cat file.list
    echo "================="

    #run
    ls -l
    $dryrun ./run_pmcs -f file.list -c parameters.rc -t 1 &> pmcs.log

    #save
    $CP pmcs.log             $outdir/pmcs_SAMPLENAME_RANDOMSEED.log
    $CP result_wen.root      $outdir/pmcs_SAMPLENAME_RANDOMSEED.root
    $CP result_wen_tree.root $outdir/pmcs_SAMPLENAME_RANDOMSEED.tree.root
}


# DELETE SAMPLE
# first test if its delete job.
if [[ SAMPLENAME == *delete* ]]
then
    #just delete and quit
    echo -n "======= deleting: "; date
    echo "       nothing to delete, it's on SAM"
    exit 0
fi


# WORK PLACE
WORKAREA=/scratch/${PBS_JOBID}
if [[ SAMPLENAME == *local* ]];
then
    WORKAREA=`pwd`
fi

cd $WORKAREA

if [[ SAMPLENAME == *local* ]];
then
    source /D0/ups/etc/setups.sh
else
    unset UPS_DIR UPS_SHELL SETUP_UPS SETUPS_DIR
    source /usr/products/etc/setups.sh
    setup setpath
    setup limit_transfers
    setup sam -q cabsrv1
    export SAM_STATION=fnal-cabsrv1

    # get kerberos certificates
    #not working 
        #scp ui3-clued0.fnal.gov:/tmp/x509up_u$UID /tmp/x509up_u$UID
        #scp ui3-clued0.fnal.gov:KERBEROSCCFILE KERBEROSCCFILE
    # from rafael
    /usr/krb5/bin/kbatch
    # On SL4 /usr/krb5/bin/klist doesn't support the -5
    # flag, while on SL5 we need it or we get an error
    # since we have no Kerberos 4 tickets
    /usr/kerberos/bin/klist -5 || return 1
    # This runs in the background and will be killed when
    # the batch system stops our job and signals the whole
    # process group.
    while true; do sleep 28000; /usr/krb5/bin/kbatch; done &
fi


$CP /prj_root/7055/wmass2/jcuth/epmcs_newTrig.tgz .
#tar -xzv --keep-newer-files -f epmcs_newTrig.tgz
tar xzvf epmcs_newTrig.tgz
cd wz_epmcs/src


echo -n "======= starting resbos: "; date
Run_resbos

if [[ SAMPLENAME == *CENTRAL* ]] # central sample just do resbos and quit
then
    ls -l
    exit 0
fi

echo -n "======= starting tupleMaker: "; date
Run_tuple_maker

echo -n "======= starting pmcs: "; date
Run_pmcs

echo -n "======= end respmcs: "; date
ls -l

exit 0
