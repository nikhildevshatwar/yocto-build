#!/bin/bash
# Author: Nikhil Devshatwar

create_release_version() {
machine=$1
baseversion=$2

	cd $topdir/temp
	baseversiondot=${baseversion//_/.}

	# Find the highest build number from previously pushed tags
	highest=`git tag -l | grep $baseversiondot | sort -nr | head -1`
	if [ "$highest" = "" ]; then
		buildnum="00"
	else
		buildnum=`echo $highest | cut -d'.' -f4`
	fi

	# Get the configs for comparison
	git show origin/latest_config_$machine:oe-configs/latest-config.txt > latest-config.txt 2>/dev/null
	cp $ARTIFACTS_PATH/config/saved-config.txt .

	# Increment the build number if config file has changed
	if ! diff saved-config.txt latest-config.txt >/dev/null 2>&1; then
		buildnum=`printf %02d $(( 10#$buildnum + 1 ))`
	fi

	version="$baseversion"_"$buildnum"
	echo $version
}

installer_generate_docs() {
machine=$1
version=$2
versiondot=$3
rtsuffix=$4

	echo "  >>> Building documentation"
	cd $topdir/temp
	rm -rf processor-sdk-doc
	git clone -q ssh://git@bitbucket.itg.ti.com/processor-sdk/processor-sdk-doc.git
	cd processor-sdk-doc
	git checkout master
	git submodule init
	git submodule update

	# Get the device family for the machine's documentation
	devfamily=`read_config_option $machine$rtsuffix documentation_family`

	make clean  DEVFAMILY=$devfamily OS=linux
	make config DEVFAMILY=$devfamily OS=linux VERSION=$version

	# Start documentation build and save the logs in artifacts
	make DEVFAMILY=$devfamily OS=linux VERSION=$version \
		> $ARTIFACTS_PATH/output/"build_documentation"
	update_build_status $? "build_documentation"
	cat $ARTIFACTS_PATH/output/"build_documentation"

	cp -r build/processor-sdk-linux-$devfamily/esd/docs/$version $ARTIFACTS_PATH/docs/
}

installer_add_tools() {
machine=$1
rtsuffix=$2

	mkdir -p $INST_PATH/board-support/
	soc=`read_config_option $machine$rtsuffix k3_respart_tool_soc`

	if [ "$soc" != "" ]; then

		echo "  >>> Adding k3-respart-tool"
		cd $topdir/temp
		git clone -q ssh://git@bitbucket.itg.ti.com/psdkla/k3-resource-partitioning.git
		cd k3-resource-partitioning
		git checkout master

		./scripts/package.sh $soc
		rm -r k3-respart-tool-*.zip
		cp -r k3-respart-tool-* $INST_PATH/board-support/k3-respart-tool
	fi
}

installer_create_binary() {
machine=$1
version=$2
versiondot=$3
rtsuffix=$4


	bundle_tar=`ls $YBD_PATH/build/arago-tmp*/deploy/images/$machine/processor-sdk-linux$rtsuffix-bundle-$machine.tar.xz`
	if [ ! -f $bundle_tar ]; then
		echo ">> ERROR: Cannot find bundle tarball at $bundle_tar"
	fi

	echo "  >>> Creating installer"
	# Copy required files for creating installer
	cp $bundle_tar $INST_PATH/
	cp $topdir/installer/ti_splash_screen.png $INST_PATH
	cp -r $ARTIFACTS_PATH/docs $INST_PATH

	# Start installer build and save log to artifacts
	$INSTALLBUILDER_PATH/bin/builder build \
		$topdir/installer/processor-sdk-linux-installer.xml linux-x64 --setvars \
		sdk_name_prefix="ti-processor-sdk-linux$rtsuffix" \
		platform_install_prefix="" \
		platform="$machine" \
		sdk_version="$versiondot" \
		sdk_loc=$INST_PATH \
		sdk_tar_name=`basename $bundle_tar` \
		output_dir=$ARTIFACTS_PATH \
	> $ARTIFACTS_PATH/output/"build_installer"

	update_build_status $? "build_installer"
	cat $ARTIFACTS_PATH/output/"build_installer"
}

create_sdk_packages() {
machine=$1
version=$2
versiondot=$3
rtsuffix=$4

	bundle_tar=`ls $YBD_PATH/build/arago-tmp*/deploy/images/$machine/processor-sdk-linux$rtsuffix-bundle-$machine.tar.xz`
	wic_image=`ls $YBD_PATH/build/arago-tmp*/deploy/images/$machine/tisdk-default-image-$machine.wic.xz`

	echo "  >>> Copying WIC image"
	cp $wic_image $ARTIFACTS_PATH/

	echo "  >>> Creating sdk-src package"
	# Only add the sources from the bundle
	cd $topdir/temp
	rm -rf sdk-src; mkdir sdk-src; cd sdk-src
	tar xf $bundle_tar
	rm -rf board-support/prebuilt-images
	tar -cf $machine-linux$rtsuffix-sdk-src-$versiondot.tar.xz board-support
	cp $machine-linux$rtsuffix-sdk-src-$versiondot.tar.xz $ARTIFACTS_PATH

	echo "  >>> Creating sdk-bin package"
	# Only add the binaries from the bundle
	cd $topdir/temp
	rm -rf sdk-bin; mkdir sdk-bin; cd sdk-bin
	tar xf $bundle_tar
	tar -cf $machine-linux$rtsuffix-sdk-bin-$versiondot.tar.xz bin/ board-support/prebuilt-images/ filesystem/ setup.sh Rules.make
	cp $machine-linux$rtsuffix-sdk-bin-$versiondot.tar.xz $ARTIFACTS_PATH

	# Copy the software manifest
	cp docs/software_manifest.txt $ARTIFACTS_PATH
	cp docs/software_manifest.htm $ARTIFACTS_PATH
}

webgen_create_release() {
machine=$1
version=$2
versiondot=$3
rtsuffix=$4

	echo "  >>> Publishing using webgen"
	EXPORTS_DIR=$topdir/temp/webgen_build/exports
	mkdir -p $topdir/temp/webgen_build $ARTIFACTS_PATH/output/webgen $EXPORTS_DIR

	# Copy the required files into exports directory
	mv $ARTIFACTS_PATH/ti-processor-sdk-linux$rtsuffix*.bin $EXPORTS_DIR/
	mv $ARTIFACTS_PATH/tisdk-default-image-$machine.wic.xz $EXPORTS_DIR/
	mv $ARTIFACTS_PATH/$machine-linux$rtsuffix-sdk-src-$versiondot.tar.xz $EXPORTS_DIR/
	mv $ARTIFACTS_PATH/$machine-linux$rtsuffix-sdk-bin-$versiondot.tar.xz $EXPORTS_DIR/
	mv $ARTIFACTS_PATH/software_manifest.txt $EXPORTS_DIR/
	mv $ARTIFACTS_PATH/software_manifest.htm $EXPORTS_DIR/
	mv $ARTIFACTS_PATH/docs $EXPORTS_DIR/

	cd $EXPORTS_DIR
	find . -maxdepth 1 -type f | grep -v md5sum.txt | xargs md5sum > md5sum.txt

	prev_version=`read_config_option $machine$rtsuffix previous_release_version`
	export TISDK_VERSION=$versiondot
	export PREV_TISDK_VERSION=$prev_version

	# Create the release using webgen
	cd $topdir/temp/webgen_build
	cp $topdir/webgen/$machine$rtsuffix/webgen.mak .

	# Start webgen build and save the log in artifacts
	$WEBGEN_PATH/exports/webgen_ext webgen.mak $ARTIFACTS_PATH/output/webgen exports \
		> $ARTIFACTS_PATH/output/"build_webgen"
	update_build_status $? "build_webgen"
	cat $ARTIFACTS_PATH/output/"build_webgen"

	# Replace symbolic links with actual contents
	cd $ARTIFACTS_PATH/output/webgen/*/$version
	dest=`readlink exports`; rm -f exports;	mv $dest .
	dest=`readlink images`;	rm -f images; cp -r $dest .
	rm -rf .validationinfo
}

create_ti_com_json() {
machine=$1
version=$2
versiondot=$3
rtsuffix=$4

	mkdir -p $ARTIFACTS_PATH/output/ti_com
	cd $ARTIFACTS_PATH/output/ti_com

	# Get the template JSON file for this machine
	jsonfile=`read_config_option $machine$rtsuffix ti_com_json`
	cp $topdir/ti_com_release/$jsonfile .

	# Fixup versions in all places
	sed -i "s@MM_NN_PP_BBB@$version@g" $jsonfile
	sed -i "s@MM.NN.PP.BBB@$versiondot@g" $jsonfile

	# Fixup file sizes from published page
	exportsdir=`cd $ARTIFACTS_PATH/output/webgen/*/$version/exports; pwd`
	for file in `ls $exportsdir`; do
		if [ ! -f $exportsdir/$file ]; then
			continue
		fi
		size=`stat --printf="%s" $exportsdir/$file`
		# This will replace the filesize for an entry in the asset whose filename matches
		jq --indent 4 '(.assets[] | select(.assetDisplayTitle == "'$file'").fileSize) = '$size'' $jsonfile > temp.json
		mv temp.json $jsonfile
	done
}
