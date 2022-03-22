#!/bin/bash
# Author: Nikhil Devshatwar

GTBUILD_SERVER="gtbuild.dal.englab.ti.com"
NIGHTLY_PATH="/data/jenkins-proc/htdocs/nightly_builds"
BACKUP_PATH="/data/tigt_qa/html/qacm/test_area"

SWDL_STAGE_SERVER="software-dl-stage.itg.ti.com"
FDS_PATH="/u1/fds"
TI_COM_OWNER="a0132237"

# This is a separate account on software-dl-stage.itg.ti.com with domain oe=le
FDS_USER_ID="gtbldadm"

sync_to_public() {
branch=$1

	echo "  >> Syncing software-dl-stage folders to public website"
	ssh $FDS_USER_ID@software-dl-stage.itg.ti.com "fds-sync --verbose --force --debug --progress $branch"
}

sync_documentation() {
platform=$1
version=$2
doc_build_id=$3

	cd $topdir/temp
	mkdir -p documentation
	echo "  >> Syncing documentation"

	# Get platform specific variable values
	swtools_folder=`read_config_option $platform swtools_folder`
	docfamily=`read_config_option $platform documentation_family`
	docs_folder=`read_config_option $platform documentation_folder`
	docs_folder=${docs_folder//VERSION/$version}
	user=`whoami`

	# copy from the jenkins server to local machine
	artifacts="$user@$GTBUILD_SERVER:$NIGHTLY_PATH/processor-sdk-doc/$doc_build_id/artifacts"
	docs_pkg="$artifacts/output/processor-sdk-linux-$docfamily/esd/docs/$version"

	rsync -a --partial-dir=.rsync --delete \
		$docs_pkg documentation

	# copy from local machine to swdl-stage server
	docs_path=`dirname $docs_folder`
	folder=`basename $docs_folder`

	if [ "$version" != "$folder" ]; then
		mv documentation/$version documentation/$folder
	fi
	swdl_dir="$FDS_USER_ID@$SWDL_STAGE_SERVER:$FDS_PATH/$docs_path"

	# Maintain FDS permissions on the server
	rsync -a --partial-dir=.rsync --delete --chmod=Dg+rws,Fg+rw \
		documentation/$folder $swdl_dir
	sync_to_public $swtools_folder
	update_build_status "$?" "build_sync_documentation"
}

sync_release_package() {
platform=$1
version=$2
rel_build_id=$3

	cd $topdir/temp
	mkdir -p release
	echo "  >> Syncing release"

	# Get platform specific variable values
	swtools_folder=`read_config_option $platform swtools_folder`
	opn=`read_config_option $platform opn`
	user=`whoami`

	# copy from the jenkins server to local machine
	artifacts="$user@$GTBUILD_SERVER:$NIGHTLY_PATH/processor-sdk-build-generic/$platform/$rel_build_id/artifacts"
	rel_pkg="$artifacts/output/webgen/${swtools_folder^^}-$opn/$version"
	rsync -a --partial-dir=.rsync --delete \
		$rel_pkg release

	# copy from local machine to swdl-stage server
	swdl_dir="$FDS_USER_ID@$SWDL_STAGE_SERVER:$FDS_PATH/$swtools_folder/esd/$opn"
	ln -svf $version latest

	# Maintain FDS permissions on the server
	rsync -a --partial-dir=.rsync --delete --chmod=Dg+rws,Fg+rw \
		release/$version latest $swdl_dir
	sync_to_public $swtools_folder
	update_build_status "$?" "build_sync_release_package"
}

sync_mirror_packages() {
	if [ `whoami` != "$FDS_USER_ID" ]; then
		echo "Current user is not $FDS_USER_ID, skipping the mirror sync"
		return
	fi

	cd $YBD_PATH
	echo "  >> Syncing packages to ti.com mirror"

	# copy from local machine to swdl-stage server (no deletion)
	downloads=`find downloads -maxdepth 1 | grep -v done | xargs echo`
	swdl_mirror_loc="$FDS_USER_ID@$SWDL_STAGE_SERVER:$FDS_PATH/processor-sdk-mirror/sources"

	# Do not use --delete flag, keep old sources, skip directories
	rsync --partial-dir=. --chmod=Dg+rws,Fg+rw \
		$downloads $swdl_mirror_loc
	sync_to_public processor-sdk-mirror
	update_build_status "$?" "build_sync_mirror_packages"
}

backup_release_package() {
platform=$1
version=$2
rel_build_id=$3

	cd $topdir/temp
	mkdir -p backup
	echo "  >> Taking backup"

	# Get platform specific variable values
	swtools_folder=`read_config_option $platform swtools_folder`
	opn=`read_config_option $platform opn`
	user=`whoami`

	# copy from nightly builds to qacm directory
	artifacts="$NIGHTLY_PATH/processor-sdk-build-generic/$platform/$rel_build_id/artifacts"
	qacm_dir="$BACKUP_PATH/${swtools_folder^^}-$opn/$version"
	ssh $user@$GTBUILD_SERVER "mkdir -p $qacm_dir; cp -r $artifacts $qacm_dir"
	update_build_status "$?" "build_backup_release_package"
}

create_ti_com_page() {
platform=$1
version=$2
rel_build_id=$3

	cd $topdir/temp
	echo "  >> Creating a page on ti.com"

	# Download and update the JSON file
	jsonfile=`read_config_option $platform ti_com_json`
	artifacts="http://gtweb.dal.design.ti.com/nightly_builds/processor-sdk-build-generic/$platform/$rel_build_id/artifacts"
	wget -q "$artifacts/output/ti_com/$jsonfile"

	# Perform final fixups on the JSON file
	date_now=`date +%s`
	sed -i "s@BUILD_DATE@$date_now@g" $jsonfile
	sed -i "s@USER_AID@$TI_COM_OWNER=@g" $jsonfile

	# Use scripts from SWTOOLS to update the ti.com metadata
	export SWTOOLS=$TOOLS_PATH/SWTOOLS
	export PYTHONPATH=${SWTOOLS}/etc:${SWTOOLS}/etc/third_party/python3:${PYTHONPATH}
	export PATH=${SWTOOLS}/bin:${PATH}
	__rel_publish -d -u $TI_COM_OWNER= -j $jsonfile -n -r .
	update_build_status "$?" "build_create_ti_com_page"
}
