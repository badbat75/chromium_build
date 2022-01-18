#!/bin/bash
set -e
me="${0}"
mypath="$(realpath $(dirname ${me}))"
workpath="${PWD}"
release=${1}
bthreads=$(nproc --ignore=1)

pushd ${workpath}/src > /dev/null
echo
. ${mypath}/environment.source
export PATH+=:${workpath}/src/third_party/depot_tools
if [ ! -z ${release} ]
then
	if [ -d out ]
	then
		echo "Remove binaries"
		rm -rf out
		echo
	fi
	if [ -f ${workpath}/.gclient_entries ]
	then
		echo "Reset sources"
		grep -v '{\|}' ${workpath}/.gclient_entries | while IFS=':' read directory url
		do
			project=$(echo ${directory} | sed "s|src/|./|;s|'||g")
			if [ -d ${project} ]
			then
				git -C ${project} reset --hard
			fi
		done
		echo
	fi
	if [ ! -d third_party/depot_tools ]
	then
		echo "Download depot_tools"
		git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git third_party/depot_tools
		echo
	fi
	echo "Check out release: ${release}"
	git checkout tags/${release}
	echo
	source chrome/VERSION
	echo "Google Chromium release: ${MAJOR}.${MINOR}.${BUILD}.${PATCH}"
	echo
	echo "Sync sources"
	gclient sync -f -D --with_branch_heads --with_tags
	echo
	echo "Patch sources"
	while IFS="," read -r patch low high
	do
		if [ ${MAJOR} -ge ${low:-${MAJOR}} ] && [ ${MAJOR} -le ${high:-${MAJOR}} ]
		then
			echo "Apply: ${patch}"
			patch -p1 < ${mypath}/patches/${patch}
		fi
	done < <( grep -v '^#' ${mypath}/patches/patch.index )
	echo
else
	source chrome/VERSION
	echo "Google Chromium release: ${MAJOR}.${MINOR}.${BUILD}.${PATCH}"
	echo
	release=${MAJOR}.${MINOR}.${BUILD}.${PATCH}
fi
echo "Read configuration"
while read -r line
do
	if [ ! "${line}" == "" ] && [[ ! "${line}" =~ \#.* ]]
	then
		defines+=" ${line}"
		case ${line} in
		esac
	fi
done < ${mypath}/chrome.config
echo "Chrome configuration: ${defines}"
echo
echo "Generate ninja files"
gn gen out/Release --args="${defines}"
echo
echo "Build chrome"
ninja -j${bthreads} -C out/Release chrome chrome_sandbox content_shell chromedriver
echo
echo "Package chrome-${release}-$(date +%Y%m%d_%H%M%S)"
tar \
	--exclude './.ninja_*' \
	--exclude './toolchain.ninja' \
	--exclude './build.ninja*' \
	--exclude './gn_logs.txt' \
	--exclude './*.runtime_deps' \
	--exclude './gen' \
	--exclude './host' \
	--exclude './obj' \
	--exclude './thinlto-cache' \
	-cf - -C out/Release . | xz -z -T${bthreads} - > ../chrome-${release}-$(date +%Y%m%d_%H%M%S).tar.xz
echo
popd > /dev/null
set +e
