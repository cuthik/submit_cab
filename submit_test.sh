#!/bin/bash

##
## @file submit_test.sh
##
## Description of the script file
##
## @author cuto <Jakub.Cuth@cern.ch>
## @date 2014-05-07

cp test_TMPL.sh scripts/test_download.sh
/usr/bin/qsub scripts/test_download.sh



exit 0
