#!/bin/bash
# Author: Nikhil Devshatwar


# This creates a file repo-revs.txt in the artifacts directory that will be
# used when creating the results.html
save_repo_revisions() {

	# List of all the Git repositories which needs to be added in the results.html
	declare -a repolist=(
		"$topdir"
		"$topdir/temp/processor-sdk-doc"
		"$topdir/temp/k3-resource-partitioning"
		"$YBD_PATH"
	)

	echo ">> Saving the repo revisions"

	# Add entries in repo-revs.txt in the following format
	# repo_URL:commit_ID:branch:comments
	for dir in ${repolist[@]}; do
		if [ ! -d $dir/.git ]; then
			echo "ERROR: $dir is not git repo"
			continue
		fi
		cd $dir

		# Replace ssh: with ssh; to avoid issues with : being separator
		repo=`git config --get remote.origin.url | tr ':' ';'`
		commit=`git rev-parse HEAD`
		branch=`git branch | grep "^\*" | sed -e 's|^* ||g'`
		comment=`git describe HEAD 2>/dev/null || echo`
		echo "$repo:$commit:$branch:$comment" >> $ARTIFACTS_PATH/repo-revs.txt
	done
}

# This will commit the saved oeconfig file in the git repo so that everyday, the
# latest OE config gets updated correctly. This makes it easy to upstream the file.
commit_release_oeconfig() {
machine=$1
version=$2
versiondot=$3

	cd $ARTIFACTS_PATH/config
	cp saved-config.txt processor-sdk-$versiondot-config.txt

	cd $topdir
	cp $ARTIFACTS_PATH/config/saved-config.txt oe-configs/latest-config.txt
	git tag $versiondot || echo

	git add oe-configs/latest-config.txt
	git commit -sm "oe-configs: Add new config for Processor SDK release $versiondot"

	if [ `whoami` == "gtbldadm" ]; then
		echo ">> Pushing the generated OE config in git"
		git push -f --tags origin HEAD:latest_config_$machine
		return
	fi
}

check_recipes() {

	report_old=0
	format_patch=0
	dump_srcinfo=0
	while [ $# -ge 1 ];
	do
		case $1 in
		"--report-old")
			shift
			report_old=1
			echo "[RECIPE-CHECKER] Checking if recipes are carrying old SRCREV"
			;;
		"--format-patch")
			shift
			format_patch=1
			echo "[RECIPE-CHECKER] Create patches for the SRCREV updates"
			;;
		"--dump-srcinfo")
			shift
			dump_srcinfo=1
			echo "[RECIPE-CHECKER] Dump source information"
			;;
		*)
			"Invalid argument: $1"
			return
			;;
		esac
	done
	cd $YBD_PATH/oe-layersetup/sources
	meta_psdkla_url=`cd meta-psdkla; git remote -v | grep fetch | awk -F" " '{ print $2 }'`

	# Find out a list of workdir and corresponding recipe with which it was built
	# This trick searches for the path of the recipe from within the package's workdir
	recipes=`grep -r srcipk-staging $YBD_PATH/oe-layersetup/build/arago-tmp-external-arm-toolchain/work/*/*/*/temp/run.do_create_srcipk
			| grep "sources/" | awk -F" " '{print $1 $3}'`
	for i in $recipes
	do
		workdir=`echo $i | cut -d ':' -f1 | rev | cut -d'/' -f3- | rev`
		recipe=`echo $i | cut -d ':' -f2`
		pushd $workdir/git 2>/dev/null 1>&2
		if [ $? -ne "0" ]; then
			continue
		fi

		# Skip all the repos which are not ti.com or arago
		git remote -v | head -1 | awk -F" " '{print $2}' | grep -E 'ti.com|arago' >/dev/null
		if [ $? -ne "0" ]; then
			popd >/dev/null
			continue
		fi

		branch=`git rev-parse --abbrev-ref HEAD`
		changes=`git diff HEAD..origin/$branch 2>/dev/null | head -100 | wc -l`
		giturl=`git remote -v | grep fetch | awk -F" " '{ print $2 }'`
		gitrepo=`echo $workdir | rev | cut -d'/' -f1-3 | rev`
		repo=$(basename $(dirname $gitrepo))
		current_uri=`git show HEAD 2>/dev/null | head -1 | cut -d' ' -f2`
		upstream_uri=`git show origin/$branch 2>/dev/null | head -1 | cut -d' ' -f2`

		#Generate the doc for src and patch information
		#TODO: Cleanup the psdkla URLs here
		if [ -d patches ]; then
			patches=""
			for p in `ls patches`
			do
				if [[ `readlink -f patches/$p` != *"meta-psdkla"* ]]; then
					continue
				fi
				patch=`readlink -f patches/$p | sed 's/.*\meta-psdkla.//'`
				if [[ $meta_psdkla_url == *"bitbucket"* ]]; then
					patches="$patches \``basename $patch` <https://bitbucket.itg.ti.com/projects/PSDKLA/repos/meta-psdkla-internal/browse/$patch?at=refs%2Fheads%2Fmaster>\`_"
				else
					patches="$patches \``basename $patch` <http://arago-project.org/git/projects/meta-psdkla.git?p=projects/meta-psdkla.git;a=blob_plain;f=$patch;hb=master>\`_"
				fi
			done
		else
			patches="N/A"
		fi
		if [ "$dump_srcinfo" == "1" ]; then
			echo "  $repo,$giturl,$branch,$current_uri,$patches"
		fi

		# Check if there are any changes between current and upstream ref
		if [ $changes -gt "0" ]; then
			name=`basename $recipe`
			giturl=`git remote -v | grep fetch | awk -F" " '{ print $2 }'`
			if [ $report_old -eq 1 ]; then
				echo
				echo
				echo "  [ERROR]: Recipe $name ignores upstream changes from $giturl"
				echo "    commit ID for WORKDIR/$gitrepo changed from $current_uri to $upstream_uri"
			fi

			# Create a patch if requested
			if [ $format_patch -ne 1 ]; then
				popd >/dev/null
				continue
			fi

			# Find all the .bb and .bbappend files to search for current commit
			list=`find $YBD_PATH/oe-layersetup/sources | grep $name`
			for j in $list
			do
				pushd `dirname $j` >/dev/null
				name=`basename $j`
				grep $current_uri $name 2>/dev/null 1>&2
				if [ $? -ne "0" ]; then
					popd >/dev/null
					continue
				fi

				# Update the SRCREV, commit, create a patch and reset
				sed -i "s/$current_uri/$upstream_uri/" $name
				git reset
				git add $name &&
				git commit -sm "$name: update SRCREV" -m "$j" &&
				git format-patch -1 -o $YBD_PATH/oe-layersetup/sources/ &&
				git reset --hard HEAD^
				popd >/dev/null
			done
			grep -r $current_uri $YBD_PATH/oe-layersetup/sources
		fi
		popd >/dev/null
	done
}
