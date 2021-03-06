#!/bin/bash
# © Copyright IBM Corporation 2019.
# LICENSE: Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0)
#
#Instructions
#Get Build script : wget https://raw.githubusercontent.com/linux-on-ibm-z/scripts/master/Python3/3.7.4/build_python3.sh
#Execute build script: bash build_python3.sh

set -e -o pipefail

PACKAGE_NAME="python"
PACKAGE_VERSION="3.7.4"
TESTS="false"
FORCE="false"
CURDIR="$(pwd)"
LOG_FILE="${CURDIR}/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"

trap "" 1 2 ERR

if [ ! -d "${CURDIR}/logs/" ]; then
	mkdir -p "${CURDIR}/logs/"
fi

# Need handling for RHEL 6.10 as it doesn't have os-release file
if [ -f "/etc/os-release" ]; then
	source "/etc/os-release"
else
	cat /etc/redhat-release >>"${LOG_FILE}"
	export ID="rhel"
	export VERSION_ID="6.x"
	export PRETTY_NAME="Red Hat Enterprise Linux 6.x"
fi

function prepare() {
	printf -- 'Preparing installation \n' |& tee -a "${LOG_FILE}"
	if command -v "sudo" >/dev/null; then
		printf -- 'Sudo : Yes\n'
	else
		printf -- 'Sudo : No \n'
		printf -- 'You can install the same from installing sudo from repository using apt, yum or zypper based on your distro. \n'
		exit 1
    fi

    printf -- "Preparing the installation for Python ${PACKAGE_VERSION}\n"

	if [[ "$FORCE" == "true" ]]; then
		printf -- 'Force attribute provided hence continuing with install without confirmation message' |& tee -a "${LOG_FILE}"
	else
		# Ask user for prerequisite installation
		printf -- "\n\nAs part of the installation some dependencies might be installed, \n"
		while true; do
			read -r -p "Do you want to continue (y/n) ? :  " yn
			case $yn in
			[Yy]*)
				printf -- 'User responded with Yes. \n' |& tee -a "${LOG_FILE}"
				break
				;;
			[Nn]*) exit ;;
			*) echo "Please provide confirmation to proceed." ;;
			esac
		done
	fi
}

function cleanup() {
	rm "$CURDIR/Python-${PACKAGE_VERSION}.tgz"
	printf -- 'Cleaned up the artifacts\n' >>"${LOG_FILE}"
}

function configureAndInstall() {
	printf -- 'Configuration and Installation started \n' |& tee -a "${LOG_FILE}"

	#Downloading Source code
	cd "${CURDIR}"
	wget "https://www.python.org/ftp/${PACKAGE_NAME}/${PACKAGE_VERSION}/Python-${PACKAGE_VERSION}.tgz"
	tar -xzvf "Python-${PACKAGE_VERSION}.tgz"

	#Configure and build and install Python3
	cd "$CURDIR/Python-${PACKAGE_VERSION}"
	./configure
	make
    sudo make install

	printf -- '\nInstalled python successfully \n' >>"${LOG_FILE}"

	#Run tests
	runTest

	#Cleanup
	cleanup

	#Verify python installation
	if command -V "$PACKAGE_NAME"${PACKAGE_VERSION:0:1} >/dev/null; then
		printf -- "%s installation completed. Please check the Usage to start the service.\n" "$PACKAGE_NAME" |& tee -a "$LOG_FILE"
	else
		printf -- "Error while installing %s, exiting with 127 \n" "$PACKAGE_NAME"
		exit 127
	fi
}

function runTest() {
	set +e
	if [[ "$TESTS" == "true" ]]; then
		printf -- "TEST Flag is set, continue with running test \n" >> "$LOG_FILE"
		cd "$CURDIR/Python-${PACKAGE_VERSION}"
		make test 2>&1| tee -a test_results.log
		printf -- "Tests completed. \n"

		if [ -s test_results.log ]; then
     	if [[ $(sed -n -e '/tests failed/,/tests skipped/ p' test_results.log) ]]; then
			printf -- '**********************************************************************************************************\n'
			printf -- 'Unexpected test failures detected. Try running the tests again: make test\n' 
            printf -- 'Or try running them individually using the command: make test TESTOPTS="-v <test_name>" \n'
			printf -- '**********************************************************************************************************\n\n'
		fi
		else
    	 printf --  '\nTest cases ran successfully without any failures\n'
		fi
	fi
	set -e
}

function logDetails() {
	printf -- '**************************** SYSTEM DETAILS *************************************************************\n' >"$LOG_FILE"
	if [ -f "/etc/os-release" ]; then
		cat "/etc/os-release" >>"$LOG_FILE"
	fi

	cat /proc/version >>"$LOG_FILE"
	printf -- '*********************************************************************************************************\n' >>"$LOG_FILE"

	printf -- "Detected %s \n" "$PRETTY_NAME"
	printf -- "Request details : PACKAGE NAME= %s , VERSION= %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" |& tee -a "$LOG_FILE"
}

# Print the usage message
function printHelp() {
	echo
	echo "Usage: "
	echo "  build_python_3.sh  [-d <debug>] [-v package-version] [-y install-without-confirmation]"
	echo "       default: If no -v specified, latest version will be installed "
	echo "This script supports Python version 3.7.4"
	echo
}

while getopts "h?dytv:" opt; do
	case "$opt" in
	h | \?)
		printHelp
		exit 0
		;;
	d)
		set -x
		;;
	v)
		PACKAGE_VERSION="$OPTARG"
		LOG_FILE="${CURDIR}/logs/${PACKAGE_NAME}-${PACKAGE_VERSION}-$(date +"%F-%T").log"
		;;
	y)
		FORCE="true"
		;;
	t)
		TESTS="true"
		;;
	esac
done

function printSummary() {
	printf -- '\n***************************************************************************************\n'
	printf -- "Run python: \n"
	printf -- "    python3 -V (To check the version) \n\n"
	printf -- '***************************************************************************************\n'
	printf -- '\n'
}

###############################################################################################################

logDetails
prepare

DISTRO="$ID-$VERSION_ID"
case "$DISTRO" in
"ubuntu-16.04" | "ubuntu-18.04" | "ubuntu-19.04")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "${LOG_FILE}"
	sudo apt-get update
	sudo apt-get install -y gcc g++ libbz2-dev libdb-dev libffi-dev libgdbm-dev liblzma-dev libncurses-dev libreadline-dev libsqlite3-dev libssl-dev make tar tk-dev uuid-dev wget xz-utils zlib1g-dev
	configureAndInstall |& tee -a "${LOG_FILE}"
	;;

"rhel-6.x")
    printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "${LOG_FILE}"
    sudo yum install -y bzip2-devel db4-devel gcc gcc-c++ gdbm-devel git libtool libffi-devel libuuid-devel make ncurses-devel tar tk-devel wget xz xz-devel zlib-devel
        cd "${CURDIR}"
        git clone git://github.com/openssl/openssl.git
        cd openssl
        git checkout OpenSSL_1_0_2l
        ./config --prefix=/usr --openssldir=/usr/local/openssl shared
        make
        sudo make install
        cd "${CURDIR}"
        wget https://ftp.gnu.org/gnu/readline/readline-6.3.tar.gz
        tar -xzvf readline-6.3.tar.gz
       cd readline-6.3
        ./configure
        make
        sudo make install
        cd "${CURDIR}"
        wget https://www.sqlite.org/src/tarball/17efb420/SQLite-17efb420.tar.gz
        tar -xzvf SQLite-17efb420.tar.gz
        cd SQLite-17efb420
        mkdir bld && cd bld
        ../configure
        make
        sudo make install
        export LD_LIBRARY_PATH=/usr/local/lib/
    configureAndInstall |& tee -a "${LOG_FILE}"
    ;;

"rhel-7.5" | "rhel-7.6" | "rhel-8.0")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "${LOG_FILE}"
  if [[ "$ID" == "rhel" && "$VERSION_ID" == "8.0" ]]; then	
  sudo yum update -y |& tee -a "$LOG_FILE"
	sudo yum install -y bzip2-devel gcc gcc-c++ gdbm-devel libdb libffi-devel libuuid make ncurses openssl readline sqlite tar tk wget xz xz zlib-devel glibc-langpack-en 
	else	
  sudo yum install -y bzip2-devel gcc gcc-c++ gdbm-devel libdb-devel libffi-devel libuuid-devel make ncurses-devel openssl-devel readline-devel sqlite-devel tar tk-devel wget xz xz-devel zlib-devel
  fi
	configureAndInstall |& tee -a "${LOG_FILE}"
	;;

"sles-12.4")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "${LOG_FILE}"
	sudo zypper install -y gawk gcc gcc-c++ gdbm-devel libbz2-devel libdb-4_8-devel libffi48-devel libopenssl-devel libuuid-devel make ncurses-devel readline-devel sqlite3-devel tar tk-devel wget xz-devel zlib-devel
	configureAndInstall |& tee -a "${LOG_FILE}"
	;;

"sles-15" | "sles-15.1")
	printf -- "Installing %s %s for %s \n" "$PACKAGE_NAME" "$PACKAGE_VERSION" "$DISTRO" |& tee -a "${LOG_FILE}"
	sudo zypper install -y gawk gcc gcc-c++ gdbm-devel libbz2-devel libdb-4_8-devel libffi-devel libnsl-devel libopenssl-devel libuuid-devel make ncurses-devel readline-devel sqlite3-devel tar tk-devel wget xz-devel zlib-devel gzip
	configureAndInstall |& tee -a "${LOG_FILE}"
	;;

*)
	printf -- "%s not supported \n" "$DISTRO" |& tee -a "${LOG_FILE}"
	exit 1
	;;
esac

printSummary |& tee -a "${LOG_FILE}"
