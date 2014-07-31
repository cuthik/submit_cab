#!/bin/bash

##
## @file respmcs_TMPL.sh
##
## template FOR CAB
##
## @author cuto <Jakub.Cuth@cern.ch>
## @date 2014-02-16

#PBS -N OUTNAME
#PBS -q sam_hi@d0cabsrv2
#PBS -j oe
#PBS -k o
#PBS -l nodes=1

# for testing the settings
DRYRUN="echo "
# !!!! uncomment line below to actualy run something !!! 
DRYRUN=

CP="${DRYRUN}cp "

#RESBOS DIR
PMCSDIR=/prj_root/7055/wmass2/jcuth/epmcs_analysis/wz_epmcs
PMCSSRC=$PMCSDIR/src

#RESBOS DIR
RESBOSINTFACE=/prj_root/7055/wmass2/jcuth/epmcs_analysis/resbosa_interface

#OUTPUT DIR
OUTDIR=/prj_root/7056/wmass2/jcuth/cabout_respmcs

jobi=`echo OUTNAME | rev | cut -d. -f1 | rev`


prepare_resbos(){
    templatein=$1
    mainout=$2
    ykout=$3

    # RESBOS ENVIRONMENT
    if [[ `uname -p` == "x86_64" ]]
    then
        echo 64
        setup root v5_26_00d -q GCC_4_5_1 -f Linux64bit+2.6-2.5
        setup cern 2004 -q x86_64
        RESBOSROOTDIR=$RESBOSINTFACE/resbos_CP_020811_64
    else
        echo 32
        setup root v5_18_00_lts3-32_py243_dzero -q gcc343:opt
        RESBOSROOTDIR=$RESBOSINTFACE/resbos_CP_020811
    fi

    #RESBOS INPUTS
    WGT=-2
    if [[ $mainout == *central* ]]
    then
        WGT=-1
    else
        $CP $OUTDIR/weights_$jobi.dat weights.dat
    fi
    #WGT=1
    ${DRYRUN}cat $templatein | sed "s|1234567|RANDOMSEED|g;s|IWGT|$WGT|g" > resbos.in
    $CP $mainout main.out
    $CP $ykout yk.out

    $CP $RESBOSROOTDIR/resbos resbos
    $CP $RESBOSINTFACE/tupleMaker/tupleMaker tupleMaker
    $CP $RESBOSINTFACE/tupleMaker/get_entries.C get_entries.C

}

run_resbos(){
    echo -n "======= starting resbos: "; date
    $DRYRUN ./resbos
    echo -n "======= resbos end: "; date
}

prepare_pmcs(){
    # PMCS ENVIRONMENT
    setup D0RunII p21.26.00 -O SRT_QUAL=maxopt
    setup lhapdf

    export TBLibraryRootPath="/rooms/wmass/hengne/TBLibrary"
    export MBLibraryRootPath="/rooms/wmass/rclsa/DATA/MBZBLibrary"
    export ZBLibraryRootPath="/rooms/wmass/rclsa/DATA/MBZBLibrary"
    export HRLibraryRootPath="/rooms/wmass/jenny/MC/HRLibrary"

    # CP EXECUTABLE INSTEAD OF COMPILATION
    $CP $PMCSSRC/run_pmcs .
    #$CP $PMCSSRC/parameters.rc.geant .
    $CP $PMCSSRC/parameters.rc .
}

run_pmcs(){
    $DRYRUN ./tupleMaker resbos.hep resbos.root
    echo -n "======= tupleMaker end: "; date
    echo -n "======= get entries: "
    root -l -b -q resbos.root get_entries.C
    echo "===== pwd and ls"
    pwd
    ls -la
    echo "===== cat file.list"
    ls resbos*.root > file.list
    cat file.list

    $DRYRUN ./run_pmcs -f file.list -c parameters.rc -t 1 | tee pmcs.log
}

# WORK PLACE
WORKAREA=/scratch/${PBS_JOBID}
cd $WORKAREA


tar xzvf /prj_root/7055/wmass2/jcuth/epmcs_pure/epmc_pure.tgz
cd wz_epmcs/src

unset UPS_DIR UPS_SHELL SETUP_UPS SETUPS_DIR
source /usr/products/etc/setups.sh
setup setpath
setup limit_transfers


#RUN
prepare_resbos $RESBOSINTFACE/input/resbos_wp_tev2_sigma_templateBIG.in \
               $RESBOSINTFACE/grids/w/1s/MAIN \
               $RESBOSINTFACE/grids/w/scn/yk_w+_tev2_ct10nn.out

run_resbos | tee resbos.log


prepare_pmcs

run_pmcs


# SAVE OUTPUTS
if [[ OUTNAME == *CENTRAL* ]]
then 
    cp weights.dat $OUTDIR/weights_$jobi.dat
fi
cp resbos.log      $OUTDIR/OUTNAME.resbos.log
cp pmcs.log        $OUTDIR/OUTNAME.pmcs.log
cp result_wen.root $OUTDIR/OUTNAME.root


exit 0
