#!/bin/bash
# Author: Nikhil Devshatwar
# This file contains all the common functions used by build and publish jobs

topdir=`git rev-parse --show-toplevel`

################################################################################
# main script starts from here

# Hard coded paths
export TOOLS_PATH="/sdk/tools"
export BUILD_PATH="/jenkins/processor-sdk-build-generic"

# Override if asked by user
if [ ! -z "$CUSTOM_BUILD_PATH" ]; then
	BUILD_PATH=$CUSTOM_BUILD_PATH
fi
if [ ! -z "$CUSTOM_TOOLS_PATH" ]; then
	TOOLS_PATH=$CUSTOM_TOOLS_PATH
fi

# Auto generated paths
export YBD_PATH=$BUILD_PATH/$release_type/yocto-build_$machine$rtsuffix
export INST_PATH=$BUILD_PATH/$release_type/installer_$machine$rtsuffix
export INSTALLBUILDER_PATH="$TOOLS_PATH/installbuilder/17.10.0"
export WEBGEN_PATH="$TOOLS_PATH/webgen"
export ARTIFACTS_PATH=$topdir/artifacts

source $topdir/scripts/setup-tasks.sh
source $topdir/scripts/yocto-build-tasks.sh
source $topdir/scripts/publish-tasks.sh
source $topdir/scripts/release-tasks.sh
source $topdir/scripts/maintenance-tasks.sh

# Add the build status in the build_targets so that this can be
# shown in the results.html page
update_build_status() {
status=$1
task=$2 

	if [ "$status" -eq "0" ]; then
		echo "$task:PASSED" >> $ARTIFACTS_PATH/output/build_targets
		touch $ARTIFACTS_PATH/output/$task
	else
		echo "$task:FAILED" >> $ARTIFACTS_PATH/output/build_targets
	fi
}

# Read the config variables fropm toplevel config.ini file
read_config_option() {
section=$1
param=$2

	$topdir/scripts/read_config.py $topdir/config.ini $section $param
}
