#!/bin/bash
# Author: Nikhil Devshatwar
# This script is used by jenkins job to perform a yocto build

# Set debug logs (-x) and fail on any command failure (-e)
set -x
set -e
platform=$1
version=$2
doc_build_id=$3
rel_build_id=$4
rel_backup=$5

topdir=`git rev-parse --show-toplevel`
source $topdir/scripts/common.sh

################################################################################
# main script starts from here
echo -e "\n\n\n\n**** STARTING JENKINS JOB now ****\n\n\n\n"

################################################################################
# Setup all the tools required for build
rm -rf $topdir/temp
mkdir -p $topdir/temp

create_dir_with_sudo $TOOLS_PATH

setup_proxy_settings

install_swtools $TOOLS_PATH

################################################################################
# Create placeholder directories/files
rm -rf $ARTIFACTS_PATH
mkdir -p $ARTIFACTS_PATH/output $topdir/temp
touch $ARTIFACTS_PATH/output/build_targets

################################################################################

################################################################################
# Copy release package to software-dl-stage.itg.ti.com
if [ ! -z $rel_build_id ] && [ $rel_build_id != "null" ]; then
	sync_release_package $platform $version $rel_build_id
	create_ti_com_page $platform $version $rel_build_id

	if [ "$rel_backup" = "true" ]; then
		backup_release_package $platform $version $rel_build_id
	fi
fi

# Copy documentation to software-dl-stage.itg.ti.com
if [ ! -z $doc_build_id ] && [ $doc_build_id != "null" ]; then
	sync_documentation $platform $version $doc_build_id
fi

echo -e "\n\n\n\n**** FINISHED JENKINS JOB ****\n\n\n\n"
# done
################################################################################
