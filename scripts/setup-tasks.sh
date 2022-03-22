#!/bin/bash
# Author: Nikhil Devshatwar

dump_vm_details() {
	# Save the details of virtual machine configuration and environment
	logpath=$ARTIFACTS_PATH/logs/linux
	mkdir -p $logpath
	cat /proc/cpuinfo > $logpath/cpuinfo.txt
	cat /proc/meminfo > $logpath/meminfo.txt
	env > $logpath/env.txt
	ulimit > $logpath/ulimit.txt
}

setup_proxy_settings() {
	# set up environment proxy
	export http_proxy=http://webproxy.ext.ti.com:80
	export https_proxy=http://webproxy.ext.ti.com:80
	export ftp_proxy=http://webproxy.ext.ti.com:80
	export no_proxy="india.ti.com,design.ti.com,itg.ti.com,dhcp.ti.com,software-dl.ti.com,sc.ti.com"

	# set up wget proxy
	echo "http_proxy=$http_proxy" > $HOME/.wgetrc
	echo "ftp_proxy=$ftp_proxy" >> $HOME/.wgetrc
	echo "https_proxy=$https_proxy" >> $HOME/.wgetrc
	echo "no_proxy=$no_proxy" >> $HOME/.wgetrc

	# set up git proxy
	if [ ! $(git config --global core.gitproxy) ]; then
		mkdir -p ~/local/bin
		echo "#!/bin/sh" > ~/local/bin/git-proxy
		echo "exec corkscrew wwwgate.ti.com 80 \$*" >> ~/local/bin/git-proxy
		chmod a+x ~/local/bin/git-proxy
		git config --global core.gitproxy "none for ti.com"
		git config --global --add core.gitproxy ~/local/bin/git-proxy
	fi

}

setup_gitconfig() {
	# set git username if not set already
	if ! git config --global user.name; then
		git config --global user.name "MPU SW Jenkins"
		git config --global user.email "mpusw_jenkins@ti.com"
	fi
}

install_host_packages() {
	if ! sudo -v; then
		echo ">> ERROR: Do not have sudo permissions to install packages"
		return
	fi
	sudo -E apt-get update
	sudo -E apt-get -y dist-upgrade

	# Install packages required for builds
	sudo -E apt-get -f -y install \
		git build-essential diffstat texinfo gawk chrpath socat doxygen \
		dos2unix python python3 bison flex libssl-dev u-boot-tools mono-devel \
		mono-complete curl python3-distutils repo pseudo python3-sphinx \
		g++-multilib libc6-dev-i386 jq cpio

	# Install packages required for debugging
	sudo -E apt-get -f -y install \
		byobu tree sysstat
}

install_installbuilder() {
dest_path=$1
	mkdir -p $dest_path
	cd $dest_path

	if [ -d $INSTALLBUILDER_PATH ]; then
		echo ">> Installbuilder already installed"
		return
	fi

	# Download and install in non interactive way
	INSTALLBUILDER_DOWNLOAD_URL="http://tigt_qa.gt.design.ti.com/qacm/test_area/nightlytools/installbuilder/installbuilder_17.10.0.tgz"
	echo ">> Downloading installbuilder"
	wget -q $INSTALLBUILDER_DOWNLOAD_URL
	tar zxf installbuilder_17.10.0.tgz -C $dest_path

	# Copy the license file for this tool
	cp $topdir/installer/license.xml $INSTALLBUILDER_PATH/
	rm installbuilder_17.10.0.tgz
}

install_webgen() {
dest_path=$1
	mkdir -p $dest_path
	cd $dest_path

	if [ -d webgen* ]; then
		echo ">> Webgen already installed"
		return
	fi

	WEBGEN_DOWNLOAD_URL="http://tigt_qa.gt.design.ti.com/qacm/test_area/nightlytools/webgen/webgen.tgz"
	echo ">> Downloading webgen"
	wget -q $WEBGEN_DOWNLOAD_URL
	tar zxf webgen.tgz -C $dest_path
	rm webgen.tgz
}

install_swtools() {
dest_path=$1

	mkdir -p $dest_path
	cd $dest_path

	if [ -d SWTOOLS ]; then
		echo ">> SWTOOLS already installed"
		return
	fi

	mkdir SWTOOLS
	cd SWTOOLS
	wget -q http://msp430.sc.ti.com/component_builds/swtools/1_46_00_06/swtools_1_46_00_06.tar.gz
	tar zxf swtools_1_46_00_06.tar.gz
}

install_compiler() {
dest_path=$1
	mkdir -p $dest_path
	cd $dest_path

	export TOOLCHAIN_PATH_ARMV7=$dest_path/gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf
	export TOOLCHAIN_PATH_ARMV8=$dest_path/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu

	if [ `ls -d gcc-arm-9.2* 2>/dev/null | wc -l` -ge 2 ]; then
		echo ">> ARM compilers already installed"
		return
	fi

	GCC_92_ARMV7="https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-arm-none-linux-gnueabihf.tar.xz"
	GCC_92_ARMV8="https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz"
	for url in "$GCC_92_ARMV7" "$GCC_92_ARMV8"; do
		echo ">> Downloading compiler"
		wget -q $url
		tar xf gcc*.xz
		rm gcc*.xz
	done
}

install_secdev_tools() {
dest_path=$1
	mkdir -p $dest_path
	cd $dest_path

	# K3 secdev is a public repo
	if [ ! -d core-secdev-k3 ]; then
		git clone git://git.ti.com/security-development-tools/core-secdev-k3.git
	fi

	cd core-secdev-k3
	git fetch --all
	git checkout master
	git reset --hard origin/master
	export TI_SECURE_DEV_PKG_K3=$dest_path/core-secdev-k3
}

create_dir_with_sudo() {
newdir=$1

	if [ ! -d $newdir ]; then
		if ! sudo -v; then
			echo ">> ERROR: Do not have sudo permissions to create dir $newdir"
		else
			sudo mkdir -p $newdir
			sudo chown -R `whoami`:$group $newdir
			install_host_packages
		fi
	fi
}
