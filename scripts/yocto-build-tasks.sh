#!/bin/bash
# Author: Nikhil Devshatwar

yocto_setup() {
oeconfig=$1

	if [ -f $topdir/oe-configs/$oeconfig ]; then
		oeconfig=$topdir/oe-configs/$oeconfig
	fi

	if [ ! -f $oeconfig ]; then
		echo "ERROR: oeconfig file does not exist. setup failed!"
		exit 1
	fi

	echo ">> Setting up yocto builds"

	# Setup the oe-layersetup repo
	cd $YBD_PATH
	git init
	git remote -v | grep origin || git remote add origin git://git.ti.com/arago-project/oe-layersetup.git
	git fetch --all
	git checkout master
	git reset --hard origin/master

	# Checkout the yocto layers based on the given oeconfig file
	./oe-layertool-setup.sh -f $oeconfig
	mkdir -p downloads

	# Save the config file used by replacing the HEAD with commit ID
	cat $oeconfig | while read line; do

		name=`echo $line | cut -d, -f1`
		ref=`echo $line | cut -d, -f4`

		# Replace HEAD with actual commit ID that was used
		if [ "$ref" == "HEAD" ]; then
			ref=`cd $YBD_PATH/sources/$name; git rev-parse HEAD`
			line=`echo $line | sed s@HEAD@$ref@`
		fi

		echo $line
	done > $ARTIFACTS_PATH/config/saved-config.txt

}

yocto_prepare() {
brand=$1
machine=$2
rt_build=$3

	echo ">> Preparing for yocto builds"
	cd $YBD_PATH/build/

	# Always use mirrors for faster builds
	echo "INHERIT += \"own-mirrors\"" >> conf/local.conf
	echo "SOURCE_MIRROR_URL = \"http://software-dl.ti.com/processor-sdk-mirror/sources/\"" >> conf/local.conf
	echo "BB_GENERATE_MIRROR_TARBALLS = \"1\"" >> conf/local.conf

	# Set the number of threads to be same as number of processors
	cpunum=`cat /proc/cpuinfo | grep processor | wc -l`
	sed -i "s/BB_NUMBER_THREADS.*/BB_NUMBER_THREADS = \"$cpunum\"/" conf/local.conf

	# Set the brand so that correct branding file is used
	if [ "$brand" != "" ]; then
		echo "ARAGO_BRAND = \"$brand\"" >> conf/local.conf
	fi

	# Handle RT builds correctly in the conf file
	if [ "$rt_build" == true ]; then
		echo "ARAGO_RT_ENABLE = \"1\"" >> conf/local.conf
		echo "ARAGO_RT_ENABLE_linux-rt = \"1\"" >> conf/local.conf
	fi

	. conf/setenv

	# Export other required variables for the yocto build
	export LC_ALL=en_US.UTF-8
	export LANG=en_US.UTF-8
	export LANGUAGE=en_US.UTF-8
	ulimit -n 4096

	echo ">> Exported required variables for yocto build"
	env
}

yocto_build() {
machine=$1
package=$2

	echo ">> Running yocto build for $package"
	for i in {1..5}
	do 
		if ! MACHINE=$machine bitbake -k $package ; then
			echo "bitbake $package build failed $i times, retrying..."
			build_status="1"
		else
			build_status="0"
			break
		fi
	done

	update_build_status "$build_status" "build_$package"

	# Save the logs in the artifacts
	logfile="arago-tmp-external-arm-glibc/log/cooker/$machine/console-latest.log"
	cp $logfile $ARTIFACTS_PATH/output/"build_$package"
}
