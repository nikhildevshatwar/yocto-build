#!/bin/bash
# Author: Nikhil Devshatwar
# This script is used by jenkins job to perform a yocto build

# Set debug logs (-x) and fail on any command failure (-e)
set -x
set -e
machine=$1
oeconfig=$2
release_type=$3
baseversion=$4
rt_build=$5

if [ $rt_build == true ]; then
	rtsuffix="-rt"
else
	rtsuffix=""
fi

topdir=`git rev-parse --show-toplevel`
source $topdir/scripts/common.sh

################################################################################
# main script starts from here
echo -e "\n\n\n\n**** STARTING JENKINS JOB now ****\n\n\n\n"

################################################################################
# Setup all the tools required for build
dump_vm_details

install_host_packages

create_dir_with_sudo $BUILD_PATH
create_dir_with_sudo $TOOLS_PATH

setup_proxy_settings
setup_gitconfig

#install_installbuilder $TOOLS_PATH
#install_webgen $TOOLS_PATH
#install_swtools $TOOLS_PATH
install_compiler $TOOLS_PATH
install_secdev_tools $TOOLS_PATH


################################################################################
# Create placeholder directories
rm -rf $INST_PATH $ARTIFACTS_PATH $topdir/temp
mkdir -p $YBD_PATH $INST_PATH $ARTIFACTS_PATH/output $ARTIFACTS_PATH/config
mkdir -p $topdir/temp

# Create placeholder files to be used for creating results.html
touch $ARTIFACTS_PATH/output/build_targets
touch $ARTIFACTS_PATH/repo-revs.txt


################################################################################
# Perform yocto builds
yocto_setup $oeconfig

yocto_prepare processor-sdk $machine $rt_build

yocto_build $machine tisdk-tiny-image
yocto_build $machine tisdk-base-image
yocto_build $machine tisdk-default-image
yocto_build $machine tisdk-docker-rootfs-image
yocto_build $machine tisdk-core-bundle


################################################################################
# Create a version for this build
version=`create_release_version $machine $baseversion`
versiondot=${version//_/.}

################################################################################
# Create the installer
installer_generate_docs $machine $version $versiondot $rtsuffix
installer_add_tools $machine $rtsuffix

installer_create_binary $machine $version $versiondot $rtsuffix


################################################################################
# Create webgen release
create_sdk_packages $machine $version $versiondot $rtsuffix

webgen_create_release $machine $version $versiondot $rtsuffix

create_ti_com_json $machine $version $versiondot $rtsuffix

################################################################################
# Create artifacts and results
save_repo_revisions

commit_release_oeconfig $machine $version $versiondot
sync_mirror_packages

echo -e "\n\n\n\n**** FINISHED JENKINS JOB ****\n\n\n\n"
# done
################################################################################
