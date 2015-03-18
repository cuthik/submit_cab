#!/bin/bash

##
## @file genpmcs_OneWeight_TMPL.sh
##
## Control script for running chain -- resbos and pmcs.
## EDITWARNING
##
## @author cuto <Jakub.Cuth@cern.ch>
## @date 2014-03-17

#PBS -N genpmcs_GENPROCESS_SAMPLENAME_RANDOMSEED
#PBS -q sam_lo@d0cabsrvNODENUM
#  #PBS -j oe
# #PBS -k oe
#PBS -k n
#PBS -o /prj_root/7056/wmass2/jcuth/cabout_logs/
#PBS -e /prj_root/7056/wmass2/jcuth/cabout_logs/
#PBS -l nodes=1

resbosintface=/prj_root/7055/wmass2/jcuth/epmcs_analysis/resbosa_interface
pythiaintface=/not/yet

outdir=/prj_root/7056/wmass2/jcuth/cabout_genpmcs
#intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateBIG.in

intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateBIGhalf.in
#intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateSMALL.in
#if [[ GENPROCESS == *local* ]]
if [ -z "${PBS_JOBID}" ];
then
    intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateSMALL.in
    #intemplate=$resbosintface/input/resbos_wp_tev2_sigma_templateBIGhalf.in
fi


usesam=yes
usesam=

#RESBOS DIR
pmcssrc=/prj_root/7055/wmass2/jcuth/epmcs_newTrigger/wz_epmcs/src

# for testing the settings
dryrun="echo "
# !!!! uncomment line below to actualy run something !!! 
dryrun=

CP="${dryrun}ln -sf "
CP="${dryrun}cp "
CP="${dryrun}rsync --copy-links --recursive --verbose --compress --update --partial --progress"

Run_resbos(){
    date > resbos.log
    pwd >> resbos.log
    # setup env
    if [[ `uname -p` == "x86_64" ]]
    then
        echo 64bit
        setup root v5_26_00d -q GCC_4_5_1 -f Linux64bit+2.6-2.5
        setup cern 2004 -q x86_64
        resbosrootdir=$resbosintface/resbos_CP_020811_64
    else
        echo 32bit
        setup root v5_18_00_lts3-32_py243_dzero -q gcc343:opt
        resbosrootdir=$resbosintface/resbos_CP_020811
    fi >> resbos.log


    # get all files
    wgt=-2
    if [[ MAIN == *CENTRAL* ]]
    then
        wgt=-1
    else
        #if [[ GENPROCESS == *local* ]];
        if [ -z "${PBS_JOBID}" ];
        then
            $CP $outdir/weight_GENPROCESS_`echo CENTRAL| sed "s|\.||g"`_RANDOMSEED.dat .
        else
            if [ $usesam ]
            then
                get_file_SAM jcuth_GENPROCESS_CENTRAL_RANDOMSEED_weight
            else
                $CP $outdir/weight_GENPROCESS_`echo CENTRAL| sed "s|\.||g"`_RANDOMSEED.dat .
            fi
        fi
        ln -sf weight_GENPROCESS_CENTRAL_RANDOMSEED.dat weights.dat
    fi >> resbos.log
    rm -rf main.out yk.out
    ${dryrun}cat $intemplate | sed "s|1234567|RANDOMSEED|g;s|IWGT|$wgt|g" > resbos.in
    $CP MAIN main.out >> resbos.log
    $CP YK yk.out >> resbos.log
    $CP $resbosrootdir/resbos resbos >> resbos.log


    #run
    ls -l >> resbos.log
    $dryrun ./resbos >> resbos.log

    #save 
    if [[ MAIN == *CENTRAL* ]]
    then
        #if [[ GENPROCESS == *local* ]];
        if [ -z "${PBS_JOBID}" ];
        then
            # put on group disk
            $CP weights.dat $outdir/weight_GENPROCESS_SAMPLENAME_RANDOMSEED.dat
            $CP resbos.hep  $outdir/GENPROCESS_SAMPLENAME_RANDOMSEED.hep
        else
            # put on group disk
            $CP weights.dat $outdir/weight_GENPROCESS_SAMPLENAME_RANDOMSEED.dat
            $CP resbos.hep  $outdir/GENPROCESS_SAMPLENAME_RANDOMSEED.hep

            if [ $usesam ]
            then
                # upload to SAM
                ssh d0mino04 " cd $outdir; ./upload_to_SAM.sh jcuth_GENPROCESS_CENTRAL_RANDOMSEED_weight weight_GENPROCESS_SAMPLENAME_RANDOMSEED.dat"
                ssh d0mino04 " cd $outdir; ./upload_to_SAM.sh jcuth_GENPROCESS_CENTRAL_RANDOMSEED_hep    GENPROCESS_SAMPLENAME_RANDOMSEED.hep"

                # remove from group disk
                rm $outdir/weight_GENPROCESS_SAMPLENAME_RANDOMSEED.dat*
                rm $outdir/GENPROCESS_SAMPLENAME_RANDOMSEED.hep*
            fi
        fi
    fi >> resbos.log
    date >> resbos.log
    $CP resbos.log $outdir/resbos_GENPROCESS_SAMPLENAME_RANDOMSEED.log

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
    os.system('ln -sf %s  .; sleep 1 &'%filename)
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

Convert_weight_and_upload(){
    date > tupleMaker.log
    pwd >> tupleMaker.log
    # setup env
    setup D0RunII p21.26.00 -O SRT_QUAL=maxopt
    source /prj_root/7055/wmass2/jcuth/DYRES/root/bin/thisroot.sh
    # get all files
    mv weights.txt weight_GENPROCESS_SAMPLENAME_RANDOMSEED.txt
    if [[ MAIN == *CENTRAL* ]]
    then
        echo "Converting should not be run for central sample."
    # else
    #     if [[ GENPROCESS == *local* ]]
    #     then
    #         ln -sf $outdir/GENPROCESS_CENTRAL_RANDOMSEED.hep GENPROCESS_CENTRAL_RANDOMSEED.hep
    #     else
    #         if [ $usesam ]
    #         then
    #             get_file_SAM jcuth_GENPROCESS_CENTRAL_RANDOMSEED_hep
    #         else
    #             $CP $outdir/GENPROCESS_CENTRAL_RANDOMSEED.hep GENPROCESS_CENTRAL_RANDOMSEED.hep
    #         fi
    #     fi
    fi >> tupleMaker.log
    $CP $resbosintface/gitTupleMaker/tupleMaker3 . >> tupleMaker.log

    # run
    ls -l >> tupleMaker.log
    ./tupleMaker3 -r weight_GENPROCESS_SAMPLENAME_RANDOMSEED.txt >> tupleMaker.log
    date >> tupleMaker.log
    echo -n "======= get entries: " >> tupleMaker.log
    ./tupleMaker3 -c weight_GENPROCESS_SAMPLENAME_RANDOMSEED.root weights >> tupleMaker.log

    # save
    #if [[ GENPROCESS == *local* ]];
    if [ -z "${PBS_JOBID}" ];
    then
        # put on group disk
        $CP weight_GENPROCESS_SAMPLENAME_RANDOMSEED.root $outdir/weight_GENPROCESS_SAMPLENAME_RANDOMSEED.root
    else
        # put on group disk
        $CP weight_GENPROCESS_SAMPLENAME_RANDOMSEED.root $outdir/weight_GENPROCESS_SAMPLENAME_RANDOMSEED.root

        if [ $usesam ]
        then
            # upload to SAM
            ssh d0mino04 " cd $outdir; ./upload_to_SAM.sh jcuth_GENPROCESS_SAMPLENAME_RANDOMSEED_weight weight_GENPROCESS_SAMPLENAME_RANDOMSEED.root"

            # remove from group disk
            rm $outdir/weight_GENPROCESS_SAMPLENAME_RANDOMSEED.root*
        fi
    fi >> tupleMaker.log
    ls -l >> tupleMaker.log
    date >> tupleMaker.log

    $CP tupleMaker.log $outdir/tupleMaker_GENPROCESS_SAMPLENAME_RANDOMSEED.log

}


Run_tuple_maker(){
    date > tupleMaker.log
    pwd >> tupleMaker.log
    # setup env
    setup D0RunII p21.26.00 -O SRT_QUAL=maxopt
    source /prj_root/7055/wmass2/jcuth/DYRES/root/bin/thisroot.sh

    # get central hep file
    #if [[ GENPROCESS == *local* ]]
    if [ -z "${PBS_JOBID}" ];
    then
        ln -sf $outdir/GENPROCESS_CENTRAL_RANDOMSEED.hep
    else
        if [ $usesam ]
        then
            get_file_SAM jcuth_GENPROCESS_CENTRAL_RANDOMSEED_hep
        else
            $CP $outdir/GENPROCESS_CENTRAL_RANDOMSEED.hep .
        fi
    fi >> tupleMaker.log

    THEFILE=GENPROCESS_CENTRAL_RANDOMSEED.hep
    if [ $usesam ]
    then
        THEFILE=`readlink GENPROCESS_CENTRAL_RANDOMSEED.hep`
        GETLINKS=linklist.txt
        readlink GENPROCESS_CENTRAL_RANDOMSEED.hep > $GETLINKS
    fi >> tupleMaker.log
    {
        echo ===== checking GENPROCESS_CENTRAL_RANDOMSEED.hep
        ls -l $THEFILE
        file $THEFILE
        head $THEFILE
        echo ...
        tail $THEFILE
        echo ===== end of check
        echo
    } >> tupleMaker.log


    # for all non central weights
    #for main in `ls -1 GRIDDIR | grep w321 | grep -v .CENTRAL.`
    for main in `ls -1 GRIDDIR | grep w321 | grep w+ | grep -v "_CENTRAL_"`;
    do
        mainBase=`basename $main .out`
        #sampleName=`echo $mainBase | rev | cut -d. -f1 | rev`
        sampleName=`echo $mainBase | grep -o "tev2_\(pmcs\)\{0,1\}[0-9]\{2\}"`
        echo weight_GENPROCESS_${sampleName}_RANDOMSEED.root
        # link weight file
        #if [[ GENPROCESS == *local* ]];
        if [ -z "${PBS_JOBID}" ];
        then
            ln -sf $outdir/weight_GENPROCESS_${sampleName}_RANDOMSEED.root
            THEFILE=`readlink weight_GENPROCESS_${sampleName}_RANDOMSEED.root`
            echo $THEFILE >> $GETLINKS
        else
            if [ $usesam ]
            then
                get_file_SAM jcuth_GENPROCESS_${sampleName}_RANDOMSEED_weight
                THEFILE=`readlink weight_GENPROCESS_${sampleName}_RANDOMSEED.root`
                echo $THEFILE >> $GETLINKS
            else
                $CP $outdir/weight_GENPROCESS_${sampleName}_RANDOMSEED.root .
            fi
        fi
    done >> tupleMaker.log

    if [ $usesam ]
    then
        ARGLIST=" "
        echo ===== checking all links:
        cat $GETLINKS
        for i in `cat $GETLINKS`
        do
            ls -l $i
            file $i
            #if [[ GENPROCESS == *local* ]]
            if [ -z "${PBS_JOBID}" ];
            then
                ARGLIST="$ARGLIST $i"
            else
                if [ $usesam ]
                then
                    ARGLIST="$ARGLIST $i"
                fi
            fi
        done
        echo ===== end of check
        echo $ARGLIST
    fi

    $CP $resbosintface/gitTupleMaker/tupleMaker3 . >> tupleMaker.log

    # run
    ls -l >> tupleMaker.log

    if [ $usesam ]
    then
        ./tupleMaker3 GENPROCESS_SAMPLENAME_RANDOMSEED.root $ARGLIST >> tupleMaker.log
    else
        ./tupleMaker3 GENPROCESS_SAMPLENAME_RANDOMSEED.root GENPROCESS_CENTRAL_RANDOMSEED.hep weight_GENPROCESS_*_RANDOMSEED.root >> tupleMaker.log
    fi >> tupleMaker.log
    echo -n "======= get entries: " >> tupleMaker.log
    ./tupleMaker3 -c GENPROCESS_SAMPLENAME_RANDOMSEED.root >> tupleMaker.log
    date >> tupleMaker.log


    # save
    $CP tupleMaker.log $outdir/tupleMaker_GENPROCESS_SAMPLENAME_RANDOMSEED.log
}

Run_pmcs(){
    date > pmcs.log
    pwd >> pmcs.log
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
    {
        $CP $pmcssrc/run_pmcs .
        $CP $pmcssrc/parameters.rc .

        ls GENPROCESS_SAMPLENAME_RANDOMSEED*.root > file.list
        echo "=== file.list ==="
        cat file.list
        echo "================="
    } >> pmcs.log

    #run
    ls -l >> pmcs.log
    echo "== running pmcs == (see log)"
    $dryrun ./run_pmcs -f file.list -c parameters.rc -t 1 >> pmcs.log

    #save
    $CP result_wen.root      $outdir/pmcs_GENPROCESS_SAMPLENAME_RANDOMSEED.root >> pmcs.log
    $CP result_wen_tree.root $outdir/pmcs_GENPROCESS_SAMPLENAME_RANDOMSEED.tree.root >> pmcs.log
    date >> pmcs.log
    $CP pmcs.log             $outdir/pmcs_GENPROCESS_SAMPLENAME_RANDOMSEED.log

    # delete
    # if successful pmcs then remove resbos files and tupleMaker3 output
}

Delete_weights(){
    rm -f $outdir/GENPROCESS_CENTRAL_RANDOMSEED.hep
    rm -f $outdir/weight_GENPROCESS_CENTRAL_RANDOMSEED.dat
    for main in `ls -1 GRIDDIR | grep w321 | grep -v .CENTRAL.`
    do
        mainBase=`basename $main .out`
        #sampleName=`echo $mainBase | rev | cut -d. -f1 | rev`
        sampleName=`echo $mainBase | grep -o "tev2_\(pmcs\)\{0,1\}[0-9]\{2\}"`
        rm -f $outdir/weight_GENPROCESS_${sampleName}_RANDOMSEED.root
    done

}



# WORK PLACE
WORKAREA=/scratch/${PBS_JOBID}
#if [[ GENPROCESS == *local* ]];
if [ -z "${PBS_JOBID}" ];
then
    WORKAREA=`pwd`
fi
cd $WORKAREA




# ENVIRONMENT
#if [[ GENPROCESS == *local* ]];
if [ -z "${PBS_JOBID}" ];
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

# PMCS OR GENERATOR
if [[ SAMPLENAME == *pmcs* ]]
then
    $CP /prj_root/7055/wmass2/jcuth/epmcs_newIII.tgz .
    #tar -xzv --keep-newer-files -f epmcs_newTrig.tgz
    #if [[ GENPROCESS == *local* ]]
    if [ -z "${PBS_JOBID}" ];
    then
        #tar xzvf epmcs_newTrig.tgz
        #tar xzvf epmcs_newIII.tgz
        echo not extracting
    else
        #tar xzvf epmcs_newTrig.tgz
        tar xzvf epmcs_newIII.tgz
    fi
    cd wz_epmcs/src

    echo -n "======= starting tupleMaker: "; date
    Run_tuple_maker
    echo -n "======= starting pmcs: "; date
    Run_pmcs
    echo -n "======= end genpmcs: "; date
    Delete_weights
    echo -n "======= weights deleted: "; date
else
    echo -n "======= starting resbos: "; date
    Run_resbos

    if [[ SAMPLENAME == *CENTRAL* ]] # central sample just do resbos and quit
    then
        ls -l
        exit 0
    fi

    echo -n "======= starting converting: "; date
    Convert_weight_and_upload
fi

ls -l
exit 0
