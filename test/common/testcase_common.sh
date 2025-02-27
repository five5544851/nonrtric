#!/bin/bash

#  ============LICENSE_START===============================================
#  Copyright (C) 2020 Nordix Foundation. All rights reserved.
#  ========================================================================
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#  ============LICENSE_END=================================================
#

# This is a script that contains all the common functions needed for auto test.
# Specific test function are defined in scripts  XXXX_functions.sh

. ../common/api_curl.sh
. ../common/testengine_config.sh

__print_args() {
	echo "Args: remote|remote-remove docker|kube --env-file <environment-filename> [release] [auto-clean] [--stop-at-error] "
	echo "      [--ricsim-prefix <prefix> ] [--use-local-image <app-nam>+]  [--use-snapshot-image <app-nam>+]"
	echo "      [--use-staging-image <app-nam>+] [--use-release-image <app-nam>+] [--image-repo <repo-address]"
	echo "      [--repo-policy local|remote] [--cluster-timeout <timeout-in seconds>] [--print-stats]"
}

if [ $# -eq 1 ] && [ "$1" == "help" ]; then

	if [ ! -z "$TC_ONELINE_DESCR" ]; then
		echo "Test script description:"
		echo $TC_ONELINE_DESCR
		echo ""
	fi
	__print_args
	echo ""
	echo "remote                -  Use images from remote repositories. Can be overridden for individual images using the '--use_xxx' flags"
	echo "remote-remove         -  Same as 'remote' but will also try to pull fresh images from remote repositories"
	echo "docker                -  Test executed in docker environment"
	echo "kube                  -  Test executed in kubernetes environment - requires an already started kubernetes environment"
	echo "--env-file            -  The script will use the supplied file to read environment variables from"
	echo "release               -  If this flag is given the script will use release version of the images"
	echo "auto-clean            -  If the function 'auto_clean_containers' is present in the end of the test script then all containers will be stopped and removed. If 'auto-clean' is not given then the function has no effect."
    echo "--stop-at-error       -  The script will stop when the first failed test or configuration"
	echo "--ricsim-prefix       -  The a1 simulator will use the supplied string as container prefix instead of 'ricsim'"
	echo "--use-local-image     -  The script will use local images for the supplied apps, space separated list of app short names"
	echo "--use-snapshot-image  -  The script will use images from the nexus snapshot repo for the supplied apps, space separated list of app short names"
	echo "--use-staging-image   -  The script will use images from the nexus staging repo for the supplied apps, space separated list of app short names"
	echo "--use-release-image   -  The script will use images from the nexus release repo for the supplied apps, space separated list of app short names"
	echo "--image-repo          -  Url to optional image repo. Only locally built images will be re-tagged and pushed to this repo"
	echo "--repo-policy         -  Policy controlling which images to re-tag and push if param --image-repo is set. Default is 'local'"
	echo "--cluster-timeout     -  Optional timeout for cluster where it takes time to obtain external ip/host-name. Timeout in seconds. "
	echo "--print-stats         -  Print current test stats after each test."

	echo ""
	echo "List of app short names supported: "$APP_SHORT_NAMES
	exit 0
fi

AUTOTEST_HOME=$PWD
# Create a test case id, ATC (Auto Test Case), from the name of the test case script.
# FTC1.sh -> ATC == FTC1
ATC=$(basename "${BASH_SOURCE[$i+1]}" .sh)

#Create result file (containing '1' for error) for this test case
#Will be replaced with a file containing '0' if all test cases pass
echo "1" > "$PWD/.result$ATC.txt"

#Formatting for 'echo' cmd
BOLD="\033[1m"
EBOLD="\033[0m"
RED="\033[31m\033[1m"
ERED="\033[0m"
GREEN="\033[32m\033[1m"
EGREEN="\033[0m"
YELLOW="\033[33m\033[1m"
EYELLOW="\033[0m"
SAMELINE="\033[0K\r"

# Just resetting any previous echo formatting...
echo -ne $EBOLD

# default test environment variables
TEST_ENV_VAR_FILE=""

echo "Test case started as: ${BASH_SOURCE[$i+1]} "$@

#Localhost constants
LOCALHOST_NAME="localhost"
LOCALHOST_HTTP="http://localhost"
LOCALHOST_HTTPS="https://localhost"

# Var to hold 'auto' in case containers shall be stopped when test case ends
AUTO_CLEAN=""

# Var to hold the app names to use local images for
USE_LOCAL_IMAGES=""

# Var to hold the app names to use remote snapshot images for
USE_SNAPSHOT_IMAGES=""

# Var to hold the app names to use remote staging images for
USE_STAGING_IMAGES=""

# Var to hold the app names to use remote release images for
USE_RELEASE_IMAGES=""


# Use this var (STOP_AT_ERROR=1 in the test script) for debugging/trouble shooting to take all logs and exit at first FAIL test case
STOP_AT_ERROR=0

# The default value "DEV" indicate that development image tags (SNAPSHOT) and nexus repos (nexus port 10002) are used.
# The value "RELEASE" indicate that relase image tag and nexus repos (nexus port) are used
# Applies only to images defined in the test-env files with image names and tags defined as XXXX_RELEASE
IMAGE_CATEGORY="DEV"

# Function to indent cmd output with one space
indent1() { sed 's/^/ /'; }

# Function to indent cmd output with two spaces
indent2() { sed 's/^/  /'; }

# Set a description string for the test case
if [ -z "$TC_ONELINE_DESCR" ]; then
	TC_ONELINE_DESCR="<no-description>"
	echo "No test case description found, TC_ONELINE_DESCR should be set on in the test script , using "$TC_ONELINE_DESCR
fi

# Counter for test suites
if [ -f .tmp_tcsuite_ctr ]; then
	tmpval=$(< .tmp_tcsuite_ctr)
	((tmpval++))
	echo $tmpval > .tmp_tcsuite_ctr
fi

# Create the logs dir if not already created in the current dir
if [ ! -d "logs" ]; then
    mkdir logs
fi
TESTLOGS=$PWD/logs

# Create the tmp dir for temporary files that is not needed after the test
# hidden files for the test env is still stored in the current dir
# files in the ./tmp is moved to ./tmp/prev when a new test is started
if [ ! -d "tmp" ]; then
    mkdir tmp
fi
curdir=$PWD
cd tmp
if [ $? -ne 0 ]; then
	echo "Cannot cd to $PWD/tmp"
	echo "Dir cannot be created. Exiting...."
fi
if [ ! -d "prev" ]; then
    mkdir prev
fi
cd $curdir
mv ./tmp/* ./tmp/prev 2> /dev/null

# Create a http message log for this testcase
HTTPLOG=$PWD"/.httplog_"$ATC".txt"
echo "" > $HTTPLOG

# Create a log dir for the test case
mkdir -p $TESTLOGS/$ATC

# Save create for current logs
mkdir -p $TESTLOGS/$ATC/previous

rm $TESTLOGS/$ATC/previous/*.log &> /dev/null
rm $TESTLOGS/$ATC/previous/*.txt &> /dev/null
rm $TESTLOGS/$ATC/previous/*.json &> /dev/null

mv  $TESTLOGS/$ATC/*.log $TESTLOGS/$ATC/previous &> /dev/null
mv  $TESTLOGS/$ATC/*.txt $TESTLOGS/$ATC/previous &> /dev/null
mv  $TESTLOGS/$ATC/*.txt $TESTLOGS/$ATC/previous &> /dev/null

# Clear the log dir for the test case
rm $TESTLOGS/$ATC/*.log &> /dev/null
rm $TESTLOGS/$ATC/*.txt &> /dev/null
rm $TESTLOGS/$ATC/*.json &> /dev/null

# Log all output from the test case to a TC log
TCLOG=$TESTLOGS/$ATC/TC.log
exec &>  >(tee ${TCLOG})

#Variables for counting tests as well as passed and failed tests
RES_TEST=0
RES_PASS=0
RES_FAIL=0
RES_CONF_FAIL=0
RES_DEVIATION=0

#Var to control if current stats shall be printed
PRINT_CURRENT_STATS=0

#File to keep deviation messages
DEVIATION_FILE=".tmp_deviations"
rm $DEVIATION_FILE &> /dev/null

# Trap "command not found" and make the script fail
trap_fnc() {

	if [ $? -eq 127 ]; then
		echo -e $RED"Function not found, setting script to FAIL"$ERED
		((RES_CONF_FAIL++))
		__print_current_stats
	fi
}
trap trap_fnc ERR

# Counter for tests
TEST_SEQUENCE_NR=1

# Function to log the start of a test case
__log_test_start() {
	TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
	echo -e $BOLD"TEST $TEST_SEQUENCE_NR (${BASH_LINENO[1]}): ${FUNCNAME[1]}" $@ $EBOLD
    echo "TEST $TEST_SEQUENCE_NR - ${TIMESTAMP}: (${BASH_LINENO[1]}): ${FUNCNAME[1]}" $@ >> $HTTPLOG
	((RES_TEST++))
	((TEST_SEQUENCE_NR++))
}

# Function to print current statistics
__print_current_stats() {
	if [ $PRINT_CURRENT_STATS -ne 0 ]; then
		echo " Currrent stats - tests, passes, fails, conf fails, deviations: $RES_TEST, $RES_PASS, $RES_FAIL, $RES_CONF_FAIL, $RES_DEVIATION"
	fi
}

# General function to log a failed test case
__log_test_fail_general() {
	echo -e $RED" FAIL."$1 $ERED
	((RES_FAIL++))
	__print_current_stats
	__check_stop_at_error
}

# Function to log a test case failed due to incorrect response code
__log_test_fail_status_code() {
	echo -e $RED" FAIL. Exepected status "$1", got "$2 $3 $ERED
	((RES_FAIL++))
	__print_current_stats
	__check_stop_at_error
}

# Function to log a test case failed due to incorrect response body
__log_test_fail_body() {
	echo -e $RED" FAIL, returned body not correct"$ERED
	((RES_FAIL++))
	__print_current_stats
	__check_stop_at_error
}

# Function to log a test case that is not supported
__log_test_fail_not_supported() {
	echo -e $RED" FAIL, function not supported"$ERED
	((RES_FAIL++))
	__print_current_stats
	__check_stop_at_error
}

# General function to log a passed test case
__log_test_pass() {
	if [ $# -gt 0 ]; then
		echo $@
	fi
	((RES_PASS++))
	echo -e $GREEN" PASS"$EGREEN
	__print_current_stats
}

#Counter for configurations
CONF_SEQUENCE_NR=1

# Function to log the start of a configuration setup
__log_conf_start() {
	TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
	echo -e $BOLD"CONF $CONF_SEQUENCE_NR (${BASH_LINENO[1]}): "${FUNCNAME[1]} $@ $EBOLD
	echo "CONF $CONF_SEQUENCE_NR - ${TIMESTAMP}: (${BASH_LINENO[1]}): "${FUNCNAME[1]} $@  >> $HTTPLOG
	((CONF_SEQUENCE_NR++))
}

# Function to log a failed configuration setup
__log_conf_fail_general() {
	echo -e $RED" FAIL."$1 $ERED
	((RES_CONF_FAIL++))
	__print_current_stats
	__check_stop_at_error
}

# Function to log a failed configuration setup due to incorrect response code
__log_conf_fail_status_code() {
	echo -e $RED" FAIL. Exepected status "$1", got "$2 $3 $ERED
	((RES_CONF_FAIL++))
	__print_current_stats
	__check_stop_at_error
}

# Function to log a failed configuration setup due to incorrect response body
__log_conf_fail_body() {
	echo -e $RED" FAIL, returned body not correct"$ERED
	((RES_CONF_FAIL++))
	__print_current_stats
	__check_stop_at_error
}

# Function to log a passed configuration setup
__log_conf_ok() {
	if [ $# -gt 0 ]; then
		echo $@
	fi
	echo -e $GREEN" OK"$EGREEN
	__print_current_stats
}

#Var for measuring execution time
TCTEST_START=$SECONDS

#File to save timer measurement results
TIMER_MEASUREMENTS=".timer_measurement.txt"
echo -e "Activity \t Duration" > $TIMER_MEASUREMENTS

# If this is set, some images (control by the parameter repo-polcy) will be re-tagged and pushed to this repo before any
IMAGE_REPO_ADR=""
IMAGE_REPO_POLICY="local"
CLUSTER_TIME_OUT=0

echo "-------------------------------------------------------------------------------------------------"
echo "-----------------------------------      Test case: "$ATC
echo "-----------------------------------      Started:   "$(date)
echo "-------------------------------------------------------------------------------------------------"
echo "-- Description: "$TC_ONELINE_DESCR
echo "-------------------------------------------------------------------------------------------------"
echo "-----------------------------------      Test case setup      -----------------------------------"

echo "Setting AUTOTEST_HOME="$AUTOTEST_HOME
START_ARG=$1
paramerror=0
paramerror_str=""
if [ $# -lt 1 ]; then
	paramerror=1
fi
if [ $paramerror -eq 0 ]; then
	if [ "$1" != "remote" ] && [ "$1" != "remote-remove" ]; then
		paramerror=1
		if [ -z "$paramerror_str" ]; then
			paramerror_str="First arg shall be 'remote' or 'remote-remove'"
		fi
	else
		shift;
	fi
fi
if [ $paramerror -eq 0 ]; then
	if [ "$1" != "docker" ] && [ "$1" != "kube" ]; then
		paramerror=1
		if [ -z "$paramerror_str" ]; then
			paramerror_str="Second arg shall be 'docker' or 'kube'"
		fi
	else
		if [ $1 == "docker" ]; then
			RUNMODE="DOCKER"
			echo "Setting RUNMODE=DOCKER"
		fi
		if [ $1 == "kube" ]; then
			RUNMODE="KUBE"
			echo "Setting RUNMODE=KUBE"
		fi
		shift;
	fi
fi
foundparm=0
while [ $paramerror -eq 0 ] && [ $foundparm -eq 0 ]; do
	foundparm=1
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "release" ]; then
			IMAGE_CATEGORY="RELEASE"
			echo "Option set - Release image tags used for applicable images "
			shift;
			foundparm=0
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "auto-clean" ]; then
			AUTO_CLEAN="auto"
			echo "Option set - Auto clean at end of test script"
			shift;
			foundparm=0
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--stop-at-error" ]; then
			STOP_AT_ERROR=1
			echo "Option set - Stop at first error"
			shift;
			foundparm=0
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--ricsim-prefix" ]; then
			shift;
			TMP_RIC_SIM_PREFIX=$1  #RIC_SIM_PREFIX need to be updated after sourcing of the env file
			if [ -z "$1" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No prefix found for flag: '--ricsim-prefix'"
				fi
			else
				echo "Option set - Overriding RIC_SIM_PREFIX with: "$1
				shift;
				foundparm=0
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--env-file" ]; then
			shift;
			TEST_ENV_VAR_FILE=$1
			if [ -z "$1" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No env file found for flag: '--env-file'"
				fi
			else
				echo "Option set - Reading test env from: "$1
				shift;
				foundparm=0
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--use-local-image" ]; then
			USE_LOCAL_IMAGES=""
			shift
			while [ $# -gt 0 ] && [[ "$1" != "--"* ]]; do
				USE_LOCAL_IMAGES=$USE_LOCAL_IMAGES" "$1
				if [[ "$AVAILABLE_IMAGES_OVERRIDE" != *"$1"* ]]; then
					paramerror=1
					if [ -z "$paramerror_str" ]; then
						paramerror_str="App name $1 is not available for local override for flag: '--use-local-image'"
					fi
				fi
				shift;
			done
			foundparm=0
			if [ -z "$USE_LOCAL_IMAGES" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No app name found for flag: '--use-local-image'"
				fi
			else
				echo "Option set - Overriding with local images for app(s):"$USE_LOCAL_IMAGES
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--use-snapshot-image" ]; then
			USE_SNAPSHOT_IMAGES=""
			shift
			while [ $# -gt 0 ] && [[ "$1" != "--"* ]]; do
				USE_SNAPSHOT_IMAGES=$USE_SNAPSHOT_IMAGES" "$1
				if [[ "$AVAILABLE_IMAGES_OVERRIDE" != *"$1"* ]]; then
					paramerror=1
					if [ -z "$paramerror_str" ]; then
						paramerror_str="App name $1 is not available for snapshot override for flag: '--use-snapshot-image'"
					fi
				fi
				shift;
			done
			foundparm=0
			if [ -z "$USE_SNAPSHOT_IMAGES" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No app name found for flag: '--use-snapshot-image'"
				fi
			else
				echo "Option set - Overriding with snapshot images for app(s):"$USE_SNAPSHOT_IMAGES
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--use-staging-image" ]; then
			USE_STAGING_IMAGES=""
			shift
			while [ $# -gt 0 ] && [[ "$1" != "--"* ]]; do
				USE_STAGING_IMAGES=$USE_STAGING_IMAGES" "$1
				if [[ "$AVAILABLE_IMAGES_OVERRIDE" != *"$1"* ]]; then
					paramerror=1
					if [ -z "$paramerror_str" ]; then
						paramerror_str="App name $1 is not available for staging override for flag: '--use-staging-image'"
					fi
				fi
				shift;
			done
			foundparm=0
			if [ -z "$USE_STAGING_IMAGES" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No app name found for flag: '--use-staging-image'"
				fi
			else
				echo "Option set - Overriding with staging images for app(s):"$USE_STAGING_IMAGES
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--use-release-image" ]; then
			USE_RELEASE_IMAGES=""
			shift
			while [ $# -gt 0 ] && [[ "$1" != "--"* ]]; do
				USE_RELEASE_IMAGES=$USE_RELEASE_IMAGES" "$1
				if [[ "$AVAILABLE_IMAGES_OVERRIDE" != *"$1"* ]]; then
					paramerror=1
					if [ -z "$paramerror_str" ]; then
						paramerror_str="App name $1 is not available for release override for flag: '--use-release-image'"
					fi
				fi
				shift;
			done
			foundparm=0
			if [ -z "$USE_RELEASE_IMAGES" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No app name found for flag: '--use-release-image'"
				fi
			else
				echo "Option set - Overriding with release images for app(s):"$USE_RELEASE_IMAGES
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--image-repo" ]; then
			shift;
			IMAGE_REPO_ADR=$1
			if [ -z "$1" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No image repo url found for : '--image-repo'"
				fi
			else
				echo "Option set - Image repo url: "$1
				shift;
				foundparm=0
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--repo-policy" ]; then
			shift;
			IMAGE_REPO_POLICY=$1
			if [ -z "$1" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No policy found for : '--repo-policy'"
				fi
			else
			    if [ "$1" == "local" ] || [ "$1" == "remote" ]; then
					echo "Option set - Image repo policy: "$1
					shift;
					foundparm=0
				else
					paramerror=1
					if [ -z "$paramerror_str" ]; then
						paramerror_str="Repo policy shall be 'local' or 'remote'"
					fi
				fi
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--cluster-timeout" ]; then
			shift;
			CLUSTER_TIME_OUT=$1
			if [ -z "$1" ]; then
				paramerror=1
				if [ -z "$paramerror_str" ]; then
					paramerror_str="No timeout value found for : '--cluster-timeout'"
				fi
			else
				#Check if positive int
				case ${CLUSTER_TIME_OUT#[+]} in
  					*[!0-9]* | '')
					  	paramerror=1
						if [ -z "$paramerror_str" ]; then
							paramerror_str="Value for '--cluster-timeout' not an int : "$CLUSTER_TIME_OUT
					  	fi
					  	;;
  					* ) ;; # Ok
				esac
				echo "Option set - Cluster timeout: "$1
				shift;
				foundparm=0
			fi
		fi
	fi
	if [ $paramerror -eq 0 ]; then
		if [ "$1" == "--print-stats" ]; then
			PRINT_CURRENT_STATS=1
			echo "Option set - Print stats"
			shift;
			foundparm=0
		fi
	fi
done
echo ""

#Still params left?
if [ $paramerror -eq 0 ] && [ $# -gt 0 ]; then
	paramerror=1
	if [ -z "$paramerror_str" ]; then
		paramerror_str="Unknown parameter(s): "$@
	fi
fi

if [ $paramerror -eq 1 ]; then
	echo -e $RED"Incorrect arg list: "$paramerror_str$ERED
	__print_args
	exit 1
fi

# sourcing the selected env variables for the test case
if [ -f "$TEST_ENV_VAR_FILE" ]; then
	echo -e $BOLD"Sourcing env vars from: "$TEST_ENV_VAR_FILE$EBOLD
	. $TEST_ENV_VAR_FILE

	if [ -z "$TEST_ENV_PROFILE" ] || [ -z "$SUPPORTED_PROFILES" ]; then
		echo -e $YELLOW"This test case may not work with selected test env file. TEST_ENV_PROFILE is missing in test_env file or SUPPORTED_PROFILES is missing in test case file"$EYELLOW
	else
		found_profile=0
		for prof in $SUPPORTED_PROFILES; do
			if [ "$TEST_ENV_PROFILE" == "$prof" ]; then
				echo -e $GREEN"Test case supports the selected test env file"$EGREEN
				found_profile=1
			fi
		done
		if [ $found_profile -ne 1 ]; then
			echo -e $RED"Test case does not support the selected test env file"$ERED
			echo "Profile: "$TEST_ENV_PROFILE"     Supported profiles: "$SUPPORTED_PROFILES
			echo -e $RED"Exiting...."$ERED
			exit 1
		fi
	fi
else
	echo -e $RED"Selected env var file does not exist: "$TEST_ENV_VAR_FILE$ERED
	echo " Select one of following env var file matching the intended target of the test"
	echo " Restart the test using the flag '--env-file <path-to-env-file>"
	ls $AUTOTEST_HOME/../common/test_env* | indent1
	exit 1
fi

#This var need be preserved from the command line option, if set, when env var is sourced.
if [ ! -z "$TMP_RIC_SIM_PREFIX" ]; then
	RIC_SIM_PREFIX=$TMP_RIC_SIM_PREFIX
fi

if [ -z "$PROJECT_IMAGES_APP_NAMES" ]; then
	echo -e $RED"Var PROJECT_IMAGES_APP_NAMES must be defined in: "$TEST_ENV_VAR_FILE $ERED
	exit 1
fi

if [[ $SUPPORTED_RUNMODES != *"$RUNMODE"* ]]; then
	echo -e $RED"This test script does not support RUNMODE $RUNMODE"$ERED
	echo "Supported RUNMODEs: "$SUPPORTED_RUNMODES
	exit 1
fi

# Choose list of included apps depending on run-mode
if [ $RUNMODE == "KUBE" ]; then
	INCLUDED_IMAGES=$KUBE_INCLUDED_IMAGES
else
	INCLUDED_IMAGES=$DOCKER_INCLUDED_IMAGES
fi

# Check needed installed sw
tmp=$(which python3)
if [ $? -ne 0 ] || [ -z tmp ]; then
	echo -e $RED"python3 is required to run the test environment, pls install"$ERED
	exit 1
fi
tmp=$(which docker)
if [ $? -ne 0 ] || [ -z tmp ]; then
	echo -e $RED"docker is required to run the test environment, pls install"$ERED
	exit 1
fi

tmp=$(which docker-compose)
if [ $? -ne 0 ] || [ -z tmp ]; then
	if [ $RUNMODE == "DOCKER" ]; then
		echo -e $RED"docker-compose is required to run the test environment, pls install"$ERED
		exit 1
	fi
fi

tmp=$(which kubectl)
if [ $? -ne 0 ] || [ -z tmp ]; then
	if [ $RUNMODE == "KUBE" ]; then
		echo -e $RED"kubectl is required to run the test environment in kubernetes mode, pls install"$ERED
		exit 1
	fi
else
	if [ $RUNMODE == "KUBE" ]; then
		res=$(kubectl cluster-info 2>&1)
		if [ $? -ne 0 ]; then
			echo -e "$BOLD$RED############################################# $ERED$EBOLD"
			echo -e  $BOLD$RED"Command 'kubectl cluster-info' returned error $ERED$EBOLD"
			echo -e "$BOLD$RED############################################# $ERED$EBOLD"
			echo " "
			echo "kubectl response:"
			echo $res
			echo " "
			echo "This script may have been started with user with no permission to run kubectl"
			echo "Try running with 'sudo' or set 'KUBECONFIG'"
			echo "Do either 1, 2 or 3 "
			echo " "
			echo "1"
			echo "Run with sudo"
			echo -e $BOLD"sudo <test-script-and-parameters>"$EBOLD
			echo " "
			echo "2"
			echo "Export KUBECONFIG and pass env to sudo - (replace user)"
			echo -e $BOLD"export KUBECONFIG='/home/<user>/.kube/config'"$EBOLD
			echo -e $BOLD"sudo -E <test-script-and-parameters>"$EBOLD
			echo " "
			echo "3"
			echo "Set KUBECONFIG inline (replace user)"
			echo -e $BOLD"sudo  KUBECONFIG='/home/<user>/.kube/config' <test-script-and-parameters>"$EBOLD

			exit 1
		fi
	fi
fi

echo -e $BOLD"Checking configured image setting for this test case"$EBOLD

#Temp var to check for image variable name errors
IMAGE_ERR=0
#Create a file with image info for later printing as a table
image_list_file="./tmp/.image-list"
echo -e "Application\tApp short name\tImage\ttag\ttag-switch" > $image_list_file

# Check if image env var is set and if so export the env var with image to use (used by docker compose files)
# arg: <app-short-name> <target-variable-name> <image-variable-name> <image-tag-variable-name> <tag-suffix> <image name>
__check_and_create_image_var() {

	if [ $# -ne 6 ]; then
		echo "Expected arg: <app-short-name> <target-variable-name> <image-variable-name> <image-tag-variable-name> <tag-suffix> <image name>"
		((IMAGE_ERR++))
		return
	fi

	__check_included_image $1
	if [ $? -ne 0 ]; then
		echo -e "$6\t$1\t<image-excluded>\t<no-tag>"  >> $image_list_file
		# Image is excluded since the corresponding app is not used in this test
		return
	fi
	tmp=${6}"\t"${1}"\t"
	#Create var from the input var names
	image="${!3}"
	tmptag=$4"_"$5
	tag="${!tmptag}"

	optional_image_repo_target=""

	if [ -z $image ]; then
		__check_ignore_image $1
		if [ $? -eq 0 ]; then
			app_ds=$6
			if [ -z "$6" ]; then
				app_ds="<app ignored>"
			fi
			echo -e "$app_ds\t$1\t<image-ignored>\t<no-tag>"  >> $image_list_file
			# Image is ignored since the corresponding the images is not set in the env file
			__remove_included_image $1   # Remove the image from the list of included images
			return
		fi
		echo -e $RED"\$"$3" not set in $TEST_ENV_VAR_FILE"$ERED
		((IMAGE_ERR++))
		echo ""
		tmp=$tmp"<no-image>\t"
	else

		optional_image_repo_target=$image

		#Add repo depending on image type
		if [ "$5" == "REMOTE_RELEASE" ]; then
			image=$NEXUS_RELEASE_REPO$image
		fi
		if [ "$5" == "REMOTE" ]; then
			image=$NEXUS_STAGING_REPO$image
		fi
		if [ "$5" == "REMOTE_SNAPSHOT" ]; then
			image=$NEXUS_SNAPSHOT_REPO$image
		fi
		if [ "$5" == "REMOTE_PROXY" ]; then
			image=$NEXUS_PROXY_REPO$image
		fi
		if [ "$5" == "REMOTE_RELEASE_ONAP" ]; then
			image=$NEXUS_RELEASE_REPO_ONAP$image
		fi
		if [ "$5" == "REMOTE_RELEASE_ORAN" ]; then
			image=$NEXUS_RELEASE_REPO_ORAN$image
		fi
		#No nexus repo added for local images, tag: LOCAL
		tmp=$tmp$image"\t"
	fi
	if [ -z $tag ]; then
		echo -e $RED"\$"$tmptag" not set in $TEST_ENV_VAR_FILE"$ERED
		((IMAGE_ERR++))
		echo ""
		tmp=$tmp"<no-tag>\t"
	else
		tmp=$tmp$tag
	fi
	tmp=$tmp"\t"$5
	echo -e "$tmp" >> $image_list_file
	#Export the env var
	export "${2}"=$image":"$tag  #Note, this var may be set to the value of the target value below in __check_and_pull_image

	remote_or_local_push=false
	if [ ! -z "$IMAGE_REPO_ADR" ] && [[ $5 != *"PROXY"* ]]; then
		if [ $5 == "LOCAL" ]; then
			remote_or_local_push=true
		fi
		if [[ $5 == *"REMOTE"* ]]; then
			if [ "$IMAGE_REPO_POLICY" == "remote" ]; then
				remote_or_local_push=true
			fi
		fi
	fi
	if $remote_or_local_push; then    # Only re-tag and push images according to policy, if repo is given
		export "${2}_SOURCE"=$image":"$tag  #Var to keep the actual source image
		if [[ $optional_image_repo_target == *"/"* ]]; then # Replace all / with _ for images to push to external repo
			optional_image_repo_target_tmp=${optional_image_repo_target//\//_}
			optional_image_repo_target=$optional_image_repo_target_tmp
		fi
		export "${2}_TARGET"=$IMAGE_REPO_ADR"/"$optional_image_repo_target":"$tag  #Create image + tag for optional image repo - pushed later if needed
	else
		export "${2}_SOURCE"=""
		export "${2}_TARGET"=""
	fi
}

# Check if app uses image included in this test run
# Returns 0 if image is included, 1 if not
__check_included_image() {
	for im in $INCLUDED_IMAGES; do
		if [ "$1" == "$im" ]; then
			return 0
		fi
	done
	return 1
}

# Check if app uses a project image
# Returns 0 if image is included, 1 if not
__check_project_image() {
	for im in $PROJECT_IMAGES; do
		if [ "$1" == "$im" ]; then
			return 0
		fi
	done
	return 1
}

# Check if app uses image built by the test script
# Returns 0 if image is included, 1 if not
__check_image_local_build() {
	for im in $LOCAL_IMAGE_BUILD; do
		if [ "$1" == "$im" ]; then
			return 0
		fi
	done
	return 1
}

# Check if app image is conditionally ignored in this test run
# Returns 0 if image is conditionally ignored, 1 if not
__check_ignore_image() {
	for im in $CONDITIONALLY_IGNORED_IMAGES; do
		if [ "$1" == "$im" ]; then
			return 0
		fi
	done
	return 1
}

# Removed image from included list of included images
# Used when an image is marked as conditionally ignored
__remove_included_image() {
	tmp_img_rem_list=""
	for im in $INCLUDED_IMAGES; do
		if [ "$1" != "$im" ]; then
			tmp_img_rem_list=$tmp_img_rem_list" "$im
		fi
	done
	INCLUDED_IMAGES=$tmp_img_rem_list
	return 0
}

# Check if app is included in the prestarted set of apps
# Returns 0 if image is included, 1 if not
__check_prestarted_image() {
	for im in $KUBE_PRESTARTED_IMAGES; do
		if [ "$1" == "$im" ]; then
			return 0
		fi
	done
	return 1
}

# Check if an app shall use a local image, based on the cmd parameters
__check_image_local_override() {
	for im in $USE_LOCAL_IMAGES; do
		if [ "$1" == "$im" ]; then
			return 1
		fi
	done
	return 0
}

# Check if app uses image override
# Returns the image/tag suffix LOCAL for local image or REMOTE/REMOTE_RELEASE/REMOTE_SNAPSHOT for staging/release/snapshot image
__check_image_override() {

	for im in $ORAN_IMAGES_APP_NAMES; do
		if [ "$1" == "$im" ]; then
			echo "REMOTE_RELEASE_ORAN"
			return 0
		fi
	done

	for im in $ONAP_IMAGES_APP_NAMES; do
		if [ "$1" == "$im" ]; then
			echo "REMOTE_RELEASE_ONAP"
			return 0
		fi
	done

	found=0
	for im in $PROJECT_IMAGES_APP_NAMES; do
		if [ "$1" == "$im" ]; then
			found=1
		fi
	done

	if [ $found -eq 0 ]; then
		echo "REMOTE_PROXY"
		return 0
	fi

	suffix=""
	if [ $IMAGE_CATEGORY == "RELEASE" ]; then
		suffix="REMOTE_RELEASE"
	fi
	if [ $IMAGE_CATEGORY == "DEV" ]; then
		suffix="REMOTE"
	fi
	CTR=0
	for im in $USE_STAGING_IMAGES; do
		if [ "$1" == "$im" ]; then
			suffix="REMOTE"
			((CTR++))
		fi
	done
	for im in $USE_RELEASE_IMAGES; do
		if [ "$1" == "$im" ]; then
			suffix="REMOTE_RELEASE"
			((CTR++))
		fi
	done
	for im in $USE_SNAPSHOT_IMAGES; do
		if [ "$1" == "$im" ]; then
			suffix="REMOTE_SNAPSHOT"
			((CTR++))
		fi
	done
	for im in $USE_LOCAL_IMAGES; do
		if [ "$1" == "$im" ]; then
			suffix="LOCAL"
			((CTR++))
		fi
	done
	echo $suffix
	if [ $CTR -gt 1 ]; then
		exit 1
	fi
	return 0
}

# Function to re-tag and image and push to another image repo
__retag_and_push_image() {
	if [ ! -z "$IMAGE_REPO_ADR" ]; then
		source_image="${!1}"
		trg_var_name=$1_"TARGET" # This var is created in func __check_and_create_image_var
		target_image="${!trg_var_name}"

		if [ -z $target_image ]; then
			return 0  # Image with no target shall not be pushed
		fi

		echo -ne "  Attempt to re-tag image to: ${BOLD}${target_image}${EBOLD}${SAMELINE}"
		tmp=$(docker image tag $source_image ${target_image} )
		if [ $? -ne 0 ]; then
			docker stop $tmp &> ./tmp/.dockererr
			((IMAGE_ERR++))
			echo ""
			echo -e "  Attempt to re-tag image to: ${BOLD}${target_image}${EBOLD} - ${RED}Failed${ERED}"
			cat ./tmp/.dockererr
			return 1
		else
			echo -e "  Attempt to re-tag image to: ${BOLD}${target_image}${EBOLD} - ${GREEN}OK${EGREEN}"
		fi
		echo -ne "  Attempt to push re-tagged image: ${BOLD}${target_image}${EBOLD}${SAMELINE}"
		tmp=$(docker push ${target_image} )
		if [ $? -ne 0 ]; then
			docker stop $tmp &> ./tmp/.dockererr
			((IMAGE_ERR++))
			echo ""
			echo -e "  Attempt to push re-tagged image: ${BOLD}${target_image}${EBOLD} - ${RED}Failed${ERED}"
			cat ./tmp/.dockererr
			return 1
		else
			echo -e "  Attempt to push re-tagged image: ${BOLD}${target_image}${EBOLD} - ${GREEN}OK${EGREEN}"
		fi
		export "${1}"=$target_image
	fi
	return 0
}

#Function to check if image exist and stop+remove the container+pull new images as needed
#args <script-start-arg> <descriptive-image-name> <container-base-name> <image-with-tag-var-name>
__check_and_pull_image() {

	source_image="${!4}"

	echo -e " Checking $BOLD$2$EBOLD container(s) with basename: $BOLD$3$EBOLD using image: $BOLD$source_image$EBOLD"
	format_string="\"{{.Repository}}\\t{{.Tag}}\\t{{.CreatedSince}}\\t{{.Size}}\""
	tmp_im=$(docker images --format $format_string $source_image)

	if [ $1 == "local" ]; then
		if [ -z "$tmp_im" ]; then
			echo -e "  "$2" (local image): \033[1m"$source_image"\033[0m $RED does not exist in local registry, need to be built (or manually pulled)"$ERED
			((IMAGE_ERR++))
			return 1
		else
			echo -e "  "$2" (local image): \033[1m"$source_image"\033[0m "$GREEN"OK"$EGREEN
		fi
	elif [ $1 == "remote" ] || [ $1 == "remote-remove" ]; then
		if [ $1 == "remote-remove" ]; then
			if [ $RUNMODE == "DOCKER" ]; then
				echo -ne "  Attempt to stop and remove container(s), if running - ${SAMELINE}"
				tmp=$(docker ps -aq --filter name=${3} --filter network=${DOCKER_SIM_NWNAME})
				if [ $? -eq 0 ] && [ ! -z "$tmp" ]; then
					docker stop $tmp &> ./tmp/.dockererr
					if [ $? -ne 0 ]; then
						((IMAGE_ERR++))
						echo ""
						echo -e $RED"  Container(s) could not be stopped - try manual stopping the container(s)"$ERED
						cat ./tmp/.dockererr
						return 1
					fi
				fi
				echo -ne "  Attempt to stop and remove container(s), if running - "$GREEN"stopped"$EGREEN"${SAMELINE}"
				tmp=$(docker ps -aq --filter name=${3} --filter network=${DOCKER_SIM_NWNAME}) &> /dev/null
				if [ $? -eq 0 ] && [ ! -z "$tmp" ]; then
					docker rm $tmp &> ./tmp/.dockererr
					if [ $? -ne 0 ]; then
						((IMAGE_ERR++))
						echo ""
						echo -e $RED"  Container(s) could not be removed - try manual removal of the container(s)"$ERED
						cat ./tmp/.dockererr
						return 1
					fi
				fi
				echo -e "  Attempt to stop and remove container(s), if running - "$GREEN"stopped removed"$EGREEN
				tmp_im=""
			else
				tmp_im=""
			fi
		fi
		if [ -z "$tmp_im" ]; then
			echo -ne "  Pulling image${SAMELINE}"
			out=$(docker pull $source_image)
			if [ $? -ne 0 ]; then
				echo ""
				echo -e "  Pulling image -$RED could not be pulled"$ERED
				((IMAGE_ERR++))
				echo $out > ./tmp/.dockererr
				echo $out
				return 1
			fi
			echo $out > ./tmp/.dockererr
			if [[ $out == *"up to date"* ]]; then
				echo -e "  Pulling image -$GREEN Image is up to date $EGREEN"
			elif [[ $out == *"Downloaded newer image"* ]]; then
				echo -e "  Pulling image -$GREEN Newer image pulled $EGREEN"
			else
				echo -e "  Pulling image -$GREEN Pulled $EGREEN"
			fi
		else
			echo -e "  Pulling image -$GREEN OK $EGREEN(exists in local repository)"
		fi
	fi

	__retag_and_push_image $4

	return $?
}

setup_testenvironment() {
	# Check that image env setting are available
	echo ""

	# Image var setup for all project images included in the test
	for imagename in $APP_SHORT_NAMES; do
		__check_included_image $imagename
		incl=$?
		__check_project_image $imagename
		proj=$?
		if [ $incl -eq 0 ]; then
			if [ $proj -eq 0 ]; then
				IMAGE_SUFFIX=$(__check_image_override $imagename)
				if [ $? -ne 0 ]; then
					echo -e $RED"Image setting from cmd line not consistent for $imagename."$ERED
					((IMAGE_ERR++))
				fi
			else
				IMAGE_SUFFIX="none"
			fi
			# A function name is created from the app short name
			# for example app short name 'ECS' -> produce the function
			# name __ECS_imagesetup
			# This function is called and is expected to exist in the imported
			# file for the ecs test functions
			# The resulting function impl will call '__check_and_create_image_var' function
			# with appropriate parameters
			# If the image suffix is none, then the component decides the suffix
			function_pointer="__"$imagename"_imagesetup"
			$function_pointer $IMAGE_SUFFIX
		fi
	done

	#Errors in image setting - exit
	if [ $IMAGE_ERR -ne 0 ]; then
		exit 1
	fi

	#Print a tables of the image settings
	echo -e $BOLD"Images configured for start arg: "$START_ARG $EBOLD
	column -t -s $'\t' $image_list_file | indent1

	echo ""

	#Set the SIM_GROUP var
	echo -e $BOLD"Setting var to main dir of all container/simulator scripts"$EBOLD
	if [ -z "$SIM_GROUP" ]; then
		SIM_GROUP=$AUTOTEST_HOME/../simulator-group
		if [ ! -d  $SIM_GROUP ]; then
			echo "Trying to set env var SIM_GROUP to dir 'simulator-group' in the nontrtric repo, but failed."
			echo -e $RED"Please set the SIM_GROUP manually in the applicable $TEST_ENV_VAR_FILE"$ERED
			exit 1
		else
			echo " SIM_GROUP auto set to: " $SIM_GROUP
		fi
	elif [ $SIM_GROUP = *simulator_group ]; then
		echo -e $RED"Env var SIM_GROUP does not seem to point to dir 'simulator-group' in the repo, check $TEST_ENV_VAR_FILE"$ERED
		exit 1
	else
		echo " SIM_GROUP env var already set to: " $SIM_GROUP
	fi

	echo ""

	#Temp var to check for image pull errors
	IMAGE_ERR=0

	# The following sequence pull the configured images


	echo -e $BOLD"Pulling configured images, if needed"$EBOLD
	if [ ! -z "$IMAGE_REPO_ADR" ] && [ $IMAGE_REPO_POLICY == "local" ]; then
		echo -e $YELLOW" Excluding all remote image check/pull when running with image repo: $IMAGE_REPO_ADR and image policy $IMAGE_REPO_POLICY"$EYELLOW
	else
		for imagename in $APP_SHORT_NAMES; do
			__check_included_image $imagename
			incl=$?
			__check_project_image $imagename
			proj=$?
			if [ $incl -eq 0 ]; then
				if [ $proj -eq 0 ]; then
					START_ARG_MOD=$START_ARG
					__check_image_local_override $imagename
					if [ $? -eq 1 ]; then
						START_ARG_MOD="local"
					fi
				else
					START_ARG_MOD=$START_ARG
				fi
				__check_image_local_build $imagename
				#No pull of images built locally
				if [ $? -ne 0 ]; then
					# A function name is created from the app short name
					# for example app short name 'HTTPPROXY' -> produce the function
					# name __HTTPPROXY_imagesetup
					# This function is called and is expected to exist in the imported
					# file for the httpproxy test functions
					# The resulting function impl will call '__check_and_pull_image' function
					# with appropriate parameters
					function_pointer="__"$imagename"_imagepull"
					$function_pointer $START_ARG_MOD $START_ARG
				fi
			else
				echo -e $YELLOW" Excluding $imagename image from image check/pull"$EYELLOW
			fi
		done
	fi

	#Errors in image setting - exit
	if [ $IMAGE_ERR -ne 0 ]; then
		echo ""
		echo "#################################################################################################"
		echo -e $RED"One or more images could not be pulled or containers using the images could not be stopped/removed"$ERED
		echo -e $RED"Or local image, overriding remote image, does not exist"$ERED
		if [ $IMAGE_CATEGORY == "DEV" ]; then
		    echo ""
			echo -e $RED"Note that SNAPSHOT and staging images may be purged from nexus after a certain period."$ERED
			echo -e $RED"In addition, the image may not have been updated in the current release so no SNAPSHOT or staging image exists"$ERED
			echo -e $RED"In these cases, switch to use a released image instead, use the flag '--use-release-image <App-short-name>'"$ERED
			echo -e $RED"Use the 'App-short-name' for the applicable image from the above table: 'Images configured for start arg'."$ERED
		fi
		echo "#################################################################################################"
		echo ""
		exit 1
	fi

	echo ""

	echo -e $BOLD"Building images needed for test"$EBOLD

	for imagename in $APP_SHORT_NAMES; do
		cd $AUTOTEST_HOME #Always reset to orig dir
		__check_image_local_build $imagename
		if [ $? -eq 0 ]; then
			__check_included_image $imagename
			if [ $? -eq 0 ]; then
				# A function name is created from the app short name
				# for example app short name 'MR' -> produce the function
				# name __MR_imagebuild
				# This function is called and is expected to exist in the imported
				# file for the mr test functions
				# The resulting function impl shall build the imagee
				function_pointer="__"$imagename"_imagebuild"
				$function_pointer

			else
				echo -e $YELLOW" Excluding image for app $imagename from image build"$EYELLOW
			fi
		fi
	done

	cd $AUTOTEST_HOME # Just to make sure...

	echo ""

	# Create a table of the images used in the script - from local repo
	echo -e $BOLD"Local docker registry images used in this test script"$EBOLD

	docker_tmp_file=./tmp/.docker-images-table
	format_string="{{.Repository}}\\t{{.Tag}}\\t{{.CreatedSince}}\\t{{.Size}}\\t{{.CreatedAt}}"
	echo -e "Application\tRepository\tTag\tCreated since\tSize\tCreated at" > $docker_tmp_file

	for imagename in $APP_SHORT_NAMES; do
		__check_included_image $imagename
		if [ $? -eq 0 ]; then
			# Only print image data if image repo is null, or if image repo is set and image is local
			print_image_data=0
			if [ -z "$IMAGE_REPO_ADR" ]; then
				print_image_data=1
			else
				__check_image_local_build $imagename
				if [ $? -eq 0 ]; then
					print_image_data=1
				fi
			fi
			if [ $print_image_data -eq 1 ]; then
				# A function name is created from the app short name
				# for example app short name 'MR' -> produce the function
				# name __MR_imagebuild
				# This function is called and is expected to exist in the imported
				# file for the mr test functions
				# The resulting function impl shall build the imagee
				function_pointer="__"$imagename"_image_data"
				$function_pointer "$format_string" $docker_tmp_file
			fi
		fi
	done

	column -t -s $'\t' $docker_tmp_file | indent1

	echo ""

	if [ ! -z "$IMAGE_REPO_ADR" ]; then

		# Create a table of the images used in the script - from remote repo
		echo -e $BOLD"Remote repo images used in this test script"$EBOLD
		echo -e $YELLOW"-- Note: These image will be pulled when the container starts. Images not managed by the test engine --"$EYELLOW

		docker_tmp_file=./tmp/.docker-images-table
		format_string="{{.Repository}}\\t{{.Tag}}"
		echo -e "Application\tRepository\tTag" > $docker_tmp_file

		for imagename in $APP_SHORT_NAMES; do
			__check_included_image $imagename
			if [ $? -eq 0 ]; then
				# Only print image data if image repo is null, or if image repo is set and image is local
				__check_image_local_build $imagename
				if [ $? -ne 0 ]; then
					# A function name is created from the app short name
					# for example app short name 'MR' -> produce the function
					# name __MR_imagebuild
					# This function is called and is expected to exist in the imported
					# file for the mr test functions
					# The resulting function impl shall build the imagee
					function_pointer="__"$imagename"_image_data"
					$function_pointer "$format_string" $docker_tmp_file
				fi
			fi
		done

		column -t -s $'\t' $docker_tmp_file | indent1

		echo ""
	fi

	if [ $RUNMODE == "KUBE" ]; then

		echo "================================================================================="
		echo "================================================================================="

		if [ -z "$IMAGE_REPO_ADR" ]; then
			echo -e $YELLOW" The image pull policy is set to 'Never' - assuming a local image repo is available for all images"$EYELLOW
			echo -e " This setting only works on single node clusters on the local machine"
			echo -e " It does not work with multi-node clusters or remote clusters. "
			export KUBE_IMAGE_PULL_POLICY="Never"
		else
			echo -e $YELLOW" The image pull policy is set to 'Always'"$EYELLOW
			echo -e " This setting work on local clusters, multi-node clusters and remote cluster. "
			echo -e " Only locally built images are managed. Remote images are always pulled from remote repos"
			echo -e " Pulling remote snapshot or staging images my in some case result in pulling newer image versions outside the control of the test engine"
			export KUBE_IMAGE_PULL_POLICY="Always"
		fi
		CLUSTER_IP=$(kubectl config view -o jsonpath={.clusters[0].cluster.server} | awk -F[/:] '{print $4}')
		echo -e $YELLOW" The cluster hostname/ip is: $CLUSTER_IP"$EYELLOW

		echo "================================================================================="
		echo "================================================================================="
		echo ""
	fi

	echo -e $BOLD"======================================================="$EBOLD
	echo -e $BOLD"== Common test setup completed -  test script begins =="$EBOLD
	echo -e $BOLD"======================================================="$EBOLD
	echo ""

}

# Function to print the test result, shall be the last cmd in a test script
# args: -
# (Function for test scripts)
print_result() {

	TCTEST_END=$SECONDS
	duration=$((TCTEST_END-TCTEST_START))

	echo "-------------------------------------------------------------------------------------------------"
	echo "-------------------------------------     Test case: "$ATC
	echo "-------------------------------------     Ended:     "$(date)
	echo "-------------------------------------------------------------------------------------------------"
	echo "-- Description: "$TC_ONELINE_DESCR
	echo "-- Execution time: " $duration " seconds"
	echo "-- Used env file: "$TEST_ENV_VAR_FILE
	echo "-------------------------------------------------------------------------------------------------"
	echo "-------------------------------------     RESULTS"
	echo ""


	if [ $RES_DEVIATION -gt 0 ]; then
		echo "Test case deviations"
		echo "===================================="
		cat $DEVIATION_FILE
	fi
	echo ""
	echo "Timer measurement in the test script"
	echo "===================================="
	column -t -s $'\t' $TIMER_MEASUREMENTS
	echo ""

	total=$((RES_PASS+RES_FAIL))
	if [ $RES_TEST -eq 0 ]; then
		echo -e "\033[1mNo tests seem to have been executed. Check the script....\033[0m"
 		echo -e "\033[31m\033[1m ___  ___ ___ ___ ___ _____   ___ _   ___ _   _   _ ___ ___ \033[0m"
 		echo -e "\033[31m\033[1m/ __|/ __| _ \_ _| _ \_   _| | __/_\ |_ _| | | | | | _ \ __|\033[0m"
		echo -e "\033[31m\033[1m\__ \ (__|   /| ||  _/ | |   | _/ _ \ | || |_| |_| |   / _| \033[0m"
 		echo -e "\033[31m\033[1m|___/\___|_|_\___|_|   |_|   |_/_/ \_\___|____\___/|_|_\___|\033[0m"
	elif [ $total != $RES_TEST ]; then
		echo -e "\033[1mTotal number of tests does not match the sum of passed and failed tests. Check the script....\033[0m"
		echo -e "\033[31m\033[1m ___  ___ ___ ___ ___ _____   ___ _   ___ _   _   _ ___ ___ \033[0m"
		echo -e "\033[31m\033[1m/ __|/ __| _ \_ _| _ \_   _| | __/_\ |_ _| | | | | | _ \ __|\033[0m"
		echo -e "\033[31m\033[1m\__ \ (__|   /| ||  _/ | |   | _/ _ \ | || |_| |_| |   / _| \033[0m"
 		echo -e "\033[31m\033[1m|___/\___|_|_\___|_|   |_|   |_/_/ \_\___|____\___/|_|_\___|\033[0m"
	elif [ $RES_CONF_FAIL -ne 0 ]; then
		echo -e "\033[1mOne or more configurations has failed. Check the script log....\033[0m"
		echo -e "\033[31m\033[1m ___  ___ ___ ___ ___ _____   ___ _   ___ _   _   _ ___ ___ \033[0m"
		echo -e "\033[31m\033[1m/ __|/ __| _ \_ _| _ \_   _| | __/_\ |_ _| | | | | | _ \ __|\033[0m"
		echo -e "\033[31m\033[1m\__ \ (__|   /| ||  _/ | |   | _/ _ \ | || |_| |_| |   / _| \033[0m"
 		echo -e "\033[31m\033[1m|___/\___|_|_\___|_|   |_|   |_/_/ \_\___|____\___/|_|_\___|\033[0m"
	elif [ $RES_PASS = $RES_TEST ]; then
		echo -e "All tests \033[32m\033[1mPASS\033[0m"
		echo -e "\033[32m\033[1m  ___  _   ___ ___ \033[0m"
		echo -e "\033[32m\033[1m | _ \/_\ / __/ __| \033[0m"
		echo -e "\033[32m\033[1m |  _/ _ \\__ \__ \\ \033[0m"
		echo -e "\033[32m\033[1m |_|/_/ \_\___/___/ \033[0m"
		echo ""

		# Update test suite counter
		if [ -f .tmp_tcsuite_pass_ctr ]; then
			tmpval=$(< .tmp_tcsuite_pass_ctr)
			((tmpval++))
			echo $tmpval > .tmp_tcsuite_pass_ctr
		fi
		if [ -f .tmp_tcsuite_pass ]; then
			echo " - "$ATC " -- "$TC_ONELINE_DESCR"  Execution time: "$duration" seconds" >> .tmp_tcsuite_pass
		fi
		#Create file with OK exit code
		echo "0" > "$AUTOTEST_HOME/.result$ATC.txt"
	else
		echo -e "One or more tests with status  \033[31m\033[1mFAIL\033[0m "
		echo -e "\033[31m\033[1m  ___ _   ___ _    \033[0m"
		echo -e "\033[31m\033[1m | __/_\ |_ _| |   \033[0m"
		echo -e "\033[31m\033[1m | _/ _ \ | || |__ \033[0m"
		echo -e "\033[31m\033[1m |_/_/ \_\___|____|\033[0m"
		echo ""
		# Update test suite counter
		if [ -f .tmp_tcsuite_fail_ctr ]; then
			tmpval=$(< .tmp_tcsuite_fail_ctr)
			((tmpval++))
			echo $tmpval > .tmp_tcsuite_fail_ctr
		fi
		if [ -f .tmp_tcsuite_fail ]; then
			echo " - "$ATC " -- "$TC_ONELINE_DESCR"  Execution time: "$duration" seconds" >> .tmp_tcsuite_fail
		fi
	fi

	echo "++++ Number of tests:          "$RES_TEST
	echo "++++ Number of passed tests:   "$RES_PASS
	echo "++++ Number of failed tests:   "$RES_FAIL
	echo ""
	echo "++++ Number of failed configs: "$RES_CONF_FAIL
	echo ""
	echo "++++ Number of test case deviations: "$RES_DEVIATION
	echo ""
	echo "-------------------------------------     Test case complete    ---------------------------------"
	echo "-------------------------------------------------------------------------------------------------"
	echo ""
}

#####################################################################
###### Functions for start, configuring, stoping, cleaning etc ######
#####################################################################

# Start timer for time measurement
# args - (any args will be printed though)
start_timer() {
	echo -e $BOLD"INFO(${BASH_LINENO[0]}): "${FUNCNAME[0]}"," $@ $EBOLD
	TC_TIMER=$SECONDS
	echo " Timer started: $(date)"
}

# Print the value of the time (in seconds)
# args - <timer message to print>  -  timer value and message will be printed both on screen
#                                     and in the timer measurement report
print_timer() {
	echo -e $BOLD"INFO(${BASH_LINENO[0]}): "${FUNCNAME[0]}"," $@ $EBOLD
	if [ $# -lt 1 ]; then
		((RES_CONF_FAIL++))
    	__print_err "need 1 or more args,  <timer message to print>" $@
		exit 1
	fi
	duration=$(($SECONDS-$TC_TIMER))
	if [ $duration -eq 0 ]; then
		duration="<1 second"
	else
		duration=$duration" seconds"
	fi
	echo " Timer duration :" $duration

	echo -e "${@:1} \t $duration" >> $TIMER_MEASUREMENTS
}

# Print the value of the time (in seconds) and reset the timer
# args - <timer message to print>  -  timer value and message will be printed both on screen
#                                     and in the timer measurement report
print_and_reset_timer() {
	echo -e $BOLD"INFO(${BASH_LINENO[0]}): "${FUNCNAME[0]}"," $@ $EBOLD
	if [ $# -lt 1 ]; then
		((RES_CONF_FAIL++))
    	__print_err "need 1 or more args,  <timer message to print>" $@
		exit 1
	fi
	duration=$(($SECONDS-$TC_TIMER))" seconds"
	if [ $duration -eq 0 ]; then
		duration="<1 second"
	else
		duration=$duration" seconds"
	fi
	echo " Timer duration :" $duration
	TC_TIMER=$SECONDS
	echo " Timer reset"

	echo -e "${@:1} \t $duration" >> $TIMER_MEASUREMENTS

}
# Print info about a deviations from intended tests
# Each deviation counted is also printed in the testreport
# args <deviation message to print>
deviation() {
	echo -e $BOLD"DEVIATION(${BASH_LINENO[0]}): "${FUNCNAME[0]} $EBOLD
	if [ $# -lt 1 ]; then
		((RES_CONF_FAIL++))
		__print_err "need 1 or more args,  <deviation message to print>" $@
		exit 1
	fi
	((RES_DEVIATION++))
	echo -e $BOLD$YELLOW" Test case deviation: ${@:1}"$EYELLOW$EBOLD
	echo "Line: ${BASH_LINENO[0]} - ${@:1}" >> $DEVIATION_FILE
	__print_current_stats
	echo ""
}

# Stop at first FAIL test case and take all logs - only for debugging/trouble shooting
__check_stop_at_error() {
	if [ $STOP_AT_ERROR -eq 1 ]; then
		echo -e $RED"Test script configured to stop at first FAIL, taking all logs and stops"$ERED
		store_logs "STOP_AT_ERROR"
		exit 1
	fi
	return 0
}

# Stop and remove all containers
# args: -
# (Not for test scripts)
__clean_containers() {

	echo -e $BOLD"Docker clean and stopping and removing all running containers, by container name"$EBOLD

	#Create empty file
	running_contr_file="./tmp/running_contr.txt"
	> $running_contr_file

	# Get list of all containers started by the test script
	for imagename in $APP_SHORT_NAMES; do
		docker ps -a --filter "label=nrttest_app=$imagename"  --filter "network=$DOCKER_SIM_NWNAME" --format ' {{.Label "nrttest_dp"}}\n{{.Label "nrttest_app"}}\n{{.Names}}' >> $running_contr_file
	done

	tab_heading1="App display name"
	tab_heading2="App short name"
	tab_heading3="Container name"

	tab_heading1_len=${#tab_heading1}
	tab_heading2_len=${#tab_heading2}
	tab_heading3_len=${#tab_heading3}
	cntr=0
	#Calc field lengths of each item in the list of containers
	while read p; do
		if (( $cntr % 3 == 0 ));then
			if [ ${#p} -gt $tab_heading1_len ]; then
				tab_heading1_len=${#p}
			fi
		fi
		if (( $cntr % 3 == 1));then
			if [ ${#p} -gt $tab_heading2_len ]; then
				tab_heading2_len=${#p}
			fi
		fi
		if (( $cntr % 3 == 2));then
			if [ ${#p} -gt $tab_heading3_len ]; then
				tab_heading3_len=${#p}
			fi
		fi
		let cntr=cntr+1
	done <$running_contr_file

	let tab_heading1_len=tab_heading1_len+2
	while (( ${#tab_heading1} < $tab_heading1_len)); do
		tab_heading1="$tab_heading1"" "
	done

	let tab_heading2_len=tab_heading2_len+2
	while (( ${#tab_heading2} < $tab_heading2_len)); do
		tab_heading2="$tab_heading2"" "
	done

	let tab_heading3_len=tab_heading3_len+2
	while (( ${#tab_heading3} < $tab_heading3_len)); do
		tab_heading3="$tab_heading3"" "
	done

	echo " $tab_heading1$tab_heading2$tab_heading3"" Actions"
	cntr=0
	while read p; do
		if (( $cntr % 3 == 0 ));then
			row=""
			heading=$p
			heading_len=$tab_heading1_len
		fi
		if (( $cntr % 3 == 1));then
			heading=$p
			heading_len=$tab_heading2_len
		fi
		if (( $cntr % 3 == 2));then
			contr=$p
			heading=$p
			heading_len=$tab_heading3_len
		fi
		while (( ${#heading} < $heading_len)); do
			heading="$heading"" "
		done
		row=$row$heading
		if (( $cntr % 3 == 2));then
			echo -ne $row$SAMELINE
			echo -ne " $row ${GREEN}stopping...${EGREEN}${SAMELINE}"
			docker stop $(docker ps -qa --filter name=${contr} --filter network=$DOCKER_SIM_NWNAME) &> /dev/null
			echo -ne " $row ${GREEN}stopped removing...${EGREEN}${SAMELINE}"
			docker rm --force $(docker ps -qa --filter name=${contr} --filter network=$DOCKER_SIM_NWNAME) &> /dev/null
			echo -e  " $row ${GREEN}stopped removed     ${EGREEN}"
		fi
		let cntr=cntr+1
	done <$running_contr_file

	echo ""

	echo -e $BOLD" Removing docker network"$EBOLD
	TMP=$(docker network ls -q --filter name=$DOCKER_SIM_NWNAME)
	if [ "$TMP" ==  $DOCKER_SIM_NWNAME ]; then
		docker network rm $DOCKER_SIM_NWNAME | indent2
		if [ $? -ne 0 ];  then
			echo -e $RED" Cannot remove docker network. Manually remove or disconnect containers from $DOCKER_SIM_NWNAME"$ERED
			exit 1
		fi
	fi
	echo -e "$GREEN  Done$EGREEN"

	echo -e $BOLD" Removing all unused docker neworks"$EBOLD
	docker network prune --force | indent2
	echo -e "$GREEN  Done$EGREEN"

	echo -e $BOLD" Removing all unused docker volumes"$EBOLD
	docker volume prune --force | indent2
	echo -e "$GREEN  Done$EGREEN"

	echo -e $BOLD" Removing all dangling/untagged docker images"$EBOLD
    docker rmi --force $(docker images -q -f dangling=true) &> /dev/null
	echo -e "$GREEN  Done$EGREEN"
	echo ""

	CONTRS=$(docker ps | awk '$1 != "CONTAINER" { n++ }; END { print n+0 }')
	if [ $? -eq 0 ]; then
		if [ $CONTRS -ne 0 ]; then
			echo -e $RED"Containers running, may cause distubance to the test case"$ERED
			docker ps -a | indent1
			echo ""
		fi
	fi
}

###################################
### Functions for kube management
###################################

# Get resource type for scaling
# args: <resource-name> <namespace>
__kube_get_resource_type() {
	kubectl get deployment $1 -n $2 1> /dev/null 2> ./tmp/kubeerr
	if [ $? -eq 0 ]; then
		echo "deployment"
		return 0
	fi
	kubectl get sts $1 -n $2 1> /dev/null 2> ./tmp/kubeerr
	if [ $? -eq 0 ]; then
		echo "sts"
		return 0
	fi
	echo "unknown-resource-type"
	return 1
}

# Scale a kube resource to a specific count
# args: <resource-type> <resource-name> <namespace> <target-count>
# (Not for test scripts)
__kube_scale() {
	echo -ne "  Setting $1 $2 replicas=$4 in namespace $3"$SAMELINE
	kubectl scale  $1 $2  -n $3 --replicas=$4 1> /dev/null 2> ./tmp/kubeerr
	if [ $? -ne 0 ]; then
		echo -e "  Setting $1 $2 replicas=$4 in namespace $3 $RED Failed $ERED"
		((RES_CONF_FAIL++))
		echo "  Message: $(<./tmp/kubeerr)"
		return 1
	else
		echo -e "  Setting $1 $2 replicas=$4 in namespace $3 $GREEN OK $EGREEN"
	fi

	TSTART=$SECONDS

	for i in {1..500}; do
		count=$(kubectl get $1/$2  -n $3 -o jsonpath='{.status.replicas}' 2> /dev/null)
		retcode=$?
		if [ -z "$count" ]; then
			#No value is sometimes returned for some reason, in case the resource has replica 0
			count=0
		fi
		if [ $retcode -ne 0 ]; then
			echo -e "$RED  Cannot fetch current replica count for $1 $2 in namespace $3 $ERED"
			((RES_CONF_FAIL++))
			return 1
		fi
		#echo ""
		if [ $count -ne $4 ]; then
			echo -ne "  Waiting for $1 $2 replicas=$4 in namespace $3. Replicas=$count after $(($SECONDS-$TSTART)) seconds $SAMELINE"
			sleep $i
		else
			echo -e "  Waiting for $1 $2 replicas=$4 in namespace $3. Replicas=$count after $(($SECONDS-$TSTART)) seconds"
			echo -e "  Replicas=$4 after $(($SECONDS-$TSTART)) seconds $GREEN OK $EGREEN"
			echo ""
			return 0
		fi
	done
	echo ""
	echo -e "$RED  Replica count did not reach target replicas=$4. Failed with replicas=$count $ERED"
	((RES_CONF_FAIL++))
	return 0
}

# Scale all kube resource sets to 0 in a namespace for resources having a certain lable and label-id
# This function does not wait for the resource to reach 0
# args: <namespace> <label-name> <label-id>
# (Not for test scripts)
__kube_scale_all_resources() {
	namespace=$1
	labelname=$2
	labelid=$3
	resources="deployment replicaset statefulset"
	for restype in $resources; do
		result=$(kubectl get $restype -n $namespace -o jsonpath='{.items[?(@.metadata.labels.'$labelname'=="'$labelid'")].metadata.name}')
		if [ $? -eq 0 ] && [ ! -z "$result" ]; then
			deleted_resourcetypes=$deleted_resourcetypes" "$restype
			for resid in $result; do
				echo -ne "  Ordered caling $restype $resid from namespace $namespace with label $labelname=$labelid to 0"$SAMELINE
				kubectl scale  $restype $resid  -n $namespace --replicas=0 1> /dev/null 2> ./tmp/kubeerr
				echo -e "  Ordered scaling $restype $resid from namespace $namespace with label $labelname=$labelid to 0 $GREEN OK $EGREEN"
			done
		fi
	done
}

# Scale all kube resource sets to 0 in a namespace for resources having a certain lable and label-id
# This function do wait for the resource to reach 0
# args: <namespace> <label-name> <label-id>
# (Not for test scripts)
__kube_scale_and_wait_all_resources() {
	namespace=$1
	labelname=$2
	labelid=$3
	resources="deployment replicaset statefulset"
	scaled_all=1
	while [ $scaled_all -ne 0 ]; do
		scaled_all=0
		for restype in $resources; do
			result=$(kubectl get $restype -n $namespace -o jsonpath='{.items[?(@.metadata.labels.'$labelname'=="'$labelid'")].metadata.name}')
			if [ $? -eq 0 ] && [ ! -z "$result" ]; then
				for resid in $result; do
					echo -e "  Ordered scaling $restype $resid from namespace $namespace with label $labelname=$labelid to 0"
					kubectl scale  $restype $resid  -n $namespace --replicas=0 1> /dev/null 2> ./tmp/kubeerr
					count=1
					T_START=$SECONDS
					while [ $count -ne 0 ]; do
						count=$(kubectl get $restype $resid  -n $namespace -o jsonpath='{.status.replicas}' 2> /dev/null)
						echo -ne "  Scaling $restype $resid from namespace $namespace with label $labelname=$labelid to 0,count=$count"$SAMELINE
						if [ $? -eq 0 ] && [ ! -z "$count" ]; then
							sleep 0.5
						else
							count=0
						fi
						duration=$(($SECONDS-$T_START))
						if [ $duration -gt 100 ]; then
							#Forcring count 0, to avoid hanging for failed scaling
							scaled_all=1
							count=0
						fi
					done
					echo -e "  Scaled $restype $resid from namespace $namespace with label $labelname=$labelid to 0,count=$count $GREEN OK $EGREEN"
				done
			fi
		done
	done
}

# Remove all kube resources in a namespace for resources having a certain label and label-id
# This function wait until the resources are gone. Scaling to 0 must have been ordered previously
# args: <namespace> <label-name> <label-id>
# (Not for test scripts)
__kube_delete_all_resources() {
	namespace=$1
	labelname=$2
	labelid=$3
	resources="deployments replicaset statefulset services pods configmaps persistentvolumeclaims persistentvolumes"
	deleted_resourcetypes=""
	for restype in $resources; do
		result=$(kubectl get $restype -n $namespace -o jsonpath='{.items[?(@.metadata.labels.'$labelname'=="'$labelid'")].metadata.name}')
		if [ $? -eq 0 ] && [ ! -z "$result" ]; then
			deleted_resourcetypes=$deleted_resourcetypes" "$restype
			for resid in $result; do
				if [ $restype == "replicaset" ] || [ $restype == "statefulset" ]; then
					count=1
					while [ $count -ne 0 ]; do
						count=$(kubectl get $restype $resid  -n $namespace -o jsonpath='{.status.replicas}' 2> /dev/null)
						echo -ne "  Scaling $restype $resid from namespace $namespace with label $labelname=$labelid to 0,count=$count"$SAMELINE
						if [ $? -eq 0 ] && [ ! -z "$count" ]; then
							sleep 0.5
						else
							count=0
						fi
					done
					echo -e "  Scaled $restype $resid from namespace $namespace with label $labelname=$labelid to 0,count=$count $GREEN OK $EGREEN"
				fi
				echo -ne "  Deleting $restype $resid from namespace $namespace with label $labelname=$labelid "$SAMELINE
				kubectl delete $restype $resid -n $namespace 1> /dev/null 2> ./tmp/kubeerr
				if [ $? -eq 0 ]; then
					echo -e "  Deleted $restype $resid from namespace $namespace with label $labelname=$labelid $GREEN OK $EGREEN"
				else
					echo -e "  Deleted $restype $resid from namespace $namespace with label $labelname=$labelid $GREEN Does not exist - OK $EGREEN"
				fi
				#fi
			done
		fi
	done
	if [ ! -z "$deleted_resourcetypes" ]; then
		for restype in $deleted_resources; do
			echo -ne "  Waiting for $restype in namespace $namespace with label $labelname=$labelid to be deleted..."$SAMELINE
			T_START=$SECONDS
			result="dummy"
			while [ ! -z "$result" ]; do
				sleep 0.5
				result=$(kubectl get $restype -n $namespace -o jsonpath='{.items[?(@.metadata.labels.'$labelname'=="'$labelid'")].metadata.name}')
				echo -ne "  Waiting for $restype in namespace $namespace with label $labelname=$labelid to be deleted...$(($SECONDS-$T_START)) seconds "$SAMELINE
				if [ -z "$result" ]; then
					echo -e " Waiting for $restype in namespace $namespace with label $labelname=$labelid to be deleted...$(($SECONDS-$T_START)) seconds $GREEN OK $EGREEN"
				elif [ $(($SECONDS-$T_START)) -gt 300 ]; then
					echo -e " Waiting for $restype in namespace $namespace with label $labelname=$labelid to be deleted...$(($SECONDS-$T_START)) seconds $RED Failed $ERED"
					result=""
				fi
			done
		done
	fi
}

# Creates a namespace if it does not exists
# args: <namespace>
# (Not for test scripts)
__kube_create_namespace() {

	#Check if test namespace exists, if not create it
	kubectl get namespace $1 1> /dev/null 2> ./tmp/kubeerr
	if [ $? -ne 0 ]; then
		echo -ne " Creating namespace "$1 $SAMELINE
		kubectl create namespace $1 1> /dev/null 2> ./tmp/kubeerr
		if [ $? -ne 0 ]; then
			echo -e " Creating namespace $1 $RED$BOLD FAILED $EBOLD$ERED"
			((RES_CONF_FAIL++))
			echo "  Message: $(<./tmp/kubeerr)"
			return 1
		else
			echo -e " Creating namespace $1 $GREEN$BOLD OK $EBOLD$EGREEN"
		fi
	else
		echo -e " Creating namespace $1 $GREEN$BOLD Already exists, OK $EBOLD$EGREEN"
	fi
	return 0
}

# Find the host ip of an app (using the service resource)
# args: <app-name> <namespace>
# (Not for test scripts)
__kube_get_service_host() {
	if [ $# -ne 2 ]; then
		((RES_CONF_FAIL++))
    	__print_err "need 2 args, <app-name> <namespace>" $@
		exit 1
	fi
	for timeout in {1..60}; do
		host=$(kubectl get svc $1  -n $2 -o jsonpath='{.spec.clusterIP}')
		if [ $? -eq 0 ]; then
			if [ ! -z "$host" ]; then
				echo $host
				return 0
			fi
		fi
		sleep 0.5
	done
	((RES_CONF_FAIL++))
	echo "host-not-found-fatal-error"
	return 1
}

# Find the named port to an app (using the service resource)
# args: <app-name> <namespace> <port-name>
# (Not for test scripts)
__kube_get_service_port() {
	if [ $# -ne 3 ]; then
		((RES_CONF_FAIL++))
    	__print_err "need 3 args, <app-name> <namespace> <port-name>" $@
		exit 1
	fi

	for timeout in {1..60}; do
		port=$(kubectl get svc $1  -n $2 -o jsonpath='{...ports[?(@.name=="'$3'")].port}')
		if [ $? -eq 0 ]; then
			if [ ! -z "$port" ]; then
				echo $port
				return 0
			fi
		fi
		sleep 0.5
	done
	((RES_CONF_FAIL++))
	echo "0"
	return 1
}

# Find the named node port to an app (using the service resource)
# args: <app-name> <namespace> <port-name>
# (Not for test scripts)
__kube_get_service_nodeport() {
	if [ $# -ne 3 ]; then
		((RES_CONF_FAIL++))
    	__print_err "need 3 args, <app-name> <namespace> <port-name>" $@
		exit 1
	fi

	for timeout in {1..60}; do
		port=$(kubectl get svc $1  -n $2 -o jsonpath='{...ports[?(@.name=="'$3'")].nodePort}')
		if [ $? -eq 0 ]; then
			if [ ! -z "$port" ]; then
				echo $port
				return 0
			fi
		fi
		sleep 0.5
	done
	((RES_CONF_FAIL++))
	echo "0"
	return 1
}

# Create a kube resource from a yaml template
# args: <resource-type> <resource-name> <template-yaml> <output-yaml>
# (Not for test scripts)
__kube_create_instance() {
	echo -ne " Creating $1 $2"$SAMELINE
	envsubst < $3 > $4
	kubectl apply -f $4 1> /dev/null 2> ./tmp/kubeerr
	if [ $? -ne 0 ]; then
		((RES_CONF_FAIL++))
		echo -e " Creating $1 $2 $RED Failed $ERED"
		echo "  Message: $(<./tmp/kubeerr)"
		return 1
	else
		echo -e " Creating $1 $2 $GREEN OK $EGREEN"
	fi
}

# Function to create a configmap in kubernetes
# args: <configmap-name> <namespace> <labelname> <labelid> <path-to-data-file> <path-to-output-yaml>
# (Not for test scripts)
__kube_create_configmap() {
	echo -ne " Creating configmap $1 "$SAMELINE
	envsubst < $5 > $5"_tmp"
	cp $5"_tmp" $5  #Need to copy back to orig file name since create configmap neeed the original file name
	kubectl create configmap $1  -n $2 --from-file=$5 --dry-run=client -o yaml > $6
	if [ $? -ne 0 ]; then
		echo -e " Creating configmap $1 $RED Failed $ERED"
		((RES_CONF_FAIL++))
		return 1
	fi

	kubectl apply -f $6 1> /dev/null 2> ./tmp/kubeerr
	if [ $? -ne 0 ]; then
		echo -e " Creating configmap $1 $RED Apply failed $ERED"
		echo "  Message: $(<./tmp/kubeerr)"
		((RES_CONF_FAIL++))
		return 1
	fi
	kubectl label configmap $1 -n $2 $3"="$4 --overwrite 1> /dev/null 2> ./tmp/kubeerr
	if [ $? -ne 0 ]; then
		echo -e " Creating configmap $1 $RED Labeling failed $ERED"
		echo "  Message: $(<./tmp/kubeerr)"
		((RES_CONF_FAIL++))
		return 1
	fi
	# Log the resulting map
	kubectl get configmap $1 -n $2 -o yaml > $6

	echo -e " Creating configmap $1 $GREEN OK $EGREEN"
	return 0
}

# This function runs a kubectl cmd where a single output value is expected, for example get ip with jsonpath filter.
# The function retries up to the timeout given in the cmd flag '--cluster-timeout'
# args: <full kubectl cmd with parameters>
# (Not for test scripts)
__kube_cmd_with_timeout() {
	TS_TMP=$(($SECONDS+$CLUSTER_TIME_OUT))

	while true; do
		kube_cmd_result=$($@)
		if [ $? -ne 0 ]; then
			kube_cmd_result=""
		fi
		if [ $SECONDS -ge $TS_TMP ] || [ ! -z "$kube_cmd_result" ] ; then
			echo $kube_cmd_result
			return 0
		fi
		sleep 1
	done
}

# This function starts a pod that cleans a the contents of a path mounted as a pvc
# After this action the pod should terminate
# This should only be executed when the pod owning the pvc is not running
# args: <appname> <namespace> <pvc-name> <path-to remove>
# (Not for test scripts)
__kube_clean_pvc() {

	export PVC_CLEANER_NAMESPACE=$2
	export PVC_CLEANER_CLAIMNAME=$3
	export PVC_CLEANER_RM_PATH=$4
	input_yaml=$SIM_GROUP"/pvc-cleaner/"pvc-cleaner.yaml
	output_yaml=$PWD/tmp/$2-pvc-cleaner.yaml

	envsubst < $input_yaml > $output_yaml

	kubectl delete -f $output_yaml 1> /dev/null 2> /dev/null   # Delete the previous terminated pod - if existing

	__kube_create_instance pod pvc-cleaner $input_yaml $output_yaml
	if [ $? -ne 0 ]; then
		echo $YELLOW" Could not clean pvc for app: $1 - persistent storage not clean - tests may not work"
		return 1
	fi

	term_ts=$(($SECONDS+30))
	while [ $term_ts -gt $SECONDS ]; do
		pod_status=$(kubectl get pod pvc-cleaner -n $PVC_CLEANER_NAMESPACE --no-headers -o custom-columns=":status.phase")
		if [ "$pod_status" == "Succeeded" ]; then
			return 0
		fi
	done
	return 1
}

# This function scales or deletes all resources for app selected by the testcase.
# args: -
# (Not for test scripts)
__clean_kube() {
	echo -e $BOLD"Initialize kube services//pods/statefulsets/replicaset to initial state"$EBOLD

	# Scale prestarted or managed apps
	for imagename in $APP_SHORT_NAMES; do
		# A function name is created from the app short name
		# for example app short name 'RICMSIM' -> produce the function
		# name __RICSIM_kube_scale_zero or __RICSIM_kube_scale_zero_and_wait
		# This function is called and is expected to exist in the imported
		# file for the ricsim test functions
		# The resulting function impl shall scale the resources to 0
		# For prestarted apps, the function waits until the resources are 0
		# For included (not prestated) apps, the scaling is just ordered
		__check_prestarted_image $imagename
		if [ $? -eq 0 ]; then
			function_pointer="__"$imagename"_kube_scale_zero_and_wait"
			echo -e " Scaling all kube resources for app $BOLD $imagename $EBOLD to 0"
			$function_pointer
		else
			__check_included_image $imagename
			if [ $? -eq 0 ]; then
				function_pointer="__"$imagename"_kube_scale_zero"
				echo -e " Scaling all kube resources for app $BOLD $imagename $EBOLD to 0"
				$function_pointer
			fi
		fi
	done

	# Delete managed apps
	for imagename in $APP_SHORT_NAMES; do
		__check_included_image $imagename
		if [ $? -eq 0 ]; then
			__check_prestarted_image $imagename
			if [ $? -ne 0 ]; then
				# A function name is created from the app short name
				# for example app short name 'RICMSIM' -> produce the function
				# name __RICSIM__kube_delete_all
				# This function is called and is expected to exist in the imported
				# file for the ricsim test functions
				# The resulting function impl shall delete all its resources
				function_pointer="__"$imagename"_kube_delete_all"
				echo -e " Deleting all kube resources for app $BOLD $imagename $EBOLD"
				$function_pointer
			fi
		fi
	done

	echo ""
}

# Function stop and remove all containers (docker) and services/deployments etc(kube)
# args: -
# Function for test script
clean_environment() {
	if [ $RUNMODE == "KUBE" ]; then
		__clean_kube
	else
		__clean_containers
	fi
}

# Function stop and remove all containers (docker) and services/deployments etc(kube) in the end of the test script, if the arg 'auto-clean' is given at test script start
# args: -
# (Function for test scripts)
auto_clean_environment() {
	echo
	if [ "$AUTO_CLEAN" == "auto" ]; then
		echo -e $BOLD"Initiating automatic cleaning of environment"$EBOLD
		clean_environment
	fi
}

# Function to sleep a test case for a numner of seconds. Prints the optional text args as info
# args: <sleep-time-in-sec> [any-text-in-quotes-to-be-printed]
# (Function for test scripts)
sleep_wait() {

	echo -e $BOLD"INFO(${BASH_LINENO[0]}): "${FUNCNAME[0]}"," $@ $EBOLD
	if [ $# -lt 1 ]; then
		((RES_CONF_FAIL++))
		__print_err "need at least one arg, <sleep-time-in-sec> [any-text-to-printed]" $@
		exit 1
	fi
	#echo "---- Sleep for " $1 " seconds ---- "$2
	start=$SECONDS
	duration=$((SECONDS-start))
	while [ $duration -lt $1 ]; do
		echo -ne "  Slept for ${duration} seconds${SAMELINE}"
		sleep 1
		duration=$((SECONDS-start))
	done
	echo -ne "  Slept for ${duration} seconds${SAMELINE}"
	echo ""
}

# Print error info for the call in the parent script (test case). Arg: <error-message-to-print>
# Not to be called from the test script itself.
__print_err() {
    echo -e $RED ${FUNCNAME[1]} " "$1" " ${BASH_SOURCE[2]} " line" ${BASH_LINENO[1]} $ERED
	if [ $# -gt 1 ]; then
		echo -e $RED" Got: "${FUNCNAME[1]} ${@:2} $ERED
	fi
	((RES_CONF_FAIL++))
}

# Function to create the docker network for the test
# Not to be called from the test script itself.
__create_docker_network() {
	tmp=$(docker network ls --format={{.Name}} --filter name=$DOCKER_SIM_NWNAME)
	if [ $? -ne 0 ]; then
		echo -e $RED" Could not check if docker network $DOCKER_SIM_NWNAME exists"$ERED
		return 1
	fi
	if [ "$tmp" != $DOCKER_SIM_NWNAME ]; then
		echo -e " Creating docker network:$BOLD $DOCKER_SIM_NWNAME $EBOLD"
		docker network create $DOCKER_SIM_NWNAME | indent2
		if [ $? -ne 0 ]; then
			echo -e $RED" Could not create docker network $DOCKER_SIM_NWNAME"$ERED
			return 1
		else
			echo -e "$GREEN  Done$EGREEN"
		fi
	else
		echo -e " Docker network $DOCKER_SIM_NWNAME already exists$GREEN OK $EGREEN"
	fi
}

# Function to start container with docker-compose and wait until all are in state running.
# If the <docker-compose-file> is empty, the default 'docker-compose.yml' is assumed.
#args: <docker-compose-dir> <docker-compose-file> <docker-compose-arg>|NODOCKERARGS <count> <app-name>+
# (Not for test scripts)
__start_container() {

	if [ $# -lt 5 ]; then
		((RES_CONF_FAIL++))
    	__print_err "need 5 or more args, <docker-compose-dir> <docker-compose-file> <docker-compose-arg>|NODOCKERARGS <count> <app-name>+" $@
		exit 1
	fi

	__create_docker_network

	curdir=$PWD
	cd $SIM_GROUP
	compose_dir=$1
	cd $1
	shift
	compose_file=$1
	if [ -z "$compose_file" ]; then
		compose_file="docker-compose.yml"
	fi
	shift
	compose_args=$1
	shift
	appcount=$1
	shift

	if [ "$compose_args" == "NODOCKERARGS" ]; then
		docker-compose -f $compose_file up -d &> .dockererr
		if [ $? -ne 0 ]; then
			echo -e $RED"Problem to launch container(s) with docker-compose"$ERED
			cat .dockererr
			echo -e $RED"Stopping script...."$ERED
			exit 1
		fi
	else
		docker-compose -f $compose_file up -d $compose_args &> .dockererr
		if [ $? -ne 0 ]; then
			echo -e $RED"Problem to launch container(s) with docker-compose"$ERED
			cat .dockererr
			echo -e $RED"Stopping script...."$ERED
			exit 1
		fi
	fi

	cd $curdir

	appindex=0
	while [ $appindex -lt $appcount ]; do
		appname=$1
		shift
		app_started=0
		for i in {1..10}; do
			if [ "$(docker inspect --format '{{ .State.Running }}' $appname)" == "true" ]; then
					echo -e " Container $BOLD${appname}$EBOLD$GREEN running$EGREEN on$BOLD image $(docker inspect --format '{{ .Config.Image }}' ${appname}) $EBOLD"
					app_started=1
					break
				else
					sleep $i
			fi
		done
		if [ $app_started -eq 0 ]; then
			((RES_CONF_FAIL++))
			echo ""
			echo -e $RED" Container $BOLD${appname}$EBOLD could not be started"$ERED
			echo -e $RED" Stopping script..."$ERED
			exit 1
		fi
		let appindex=appindex+1
	done
	return 0
}

# Function to check if container/service is responding to http/https
# args: <container-name>|<service-name> url
# (Not for test scripts)
__check_service_start() {

	if [ $# -ne 2 ]; then
		((RES_CONF_FAIL++))
		__print_err "need 2 args, <container-name>|<service-name> url" $@
		return 1
	fi

	if [ $RUNMODE == "KUBE" ]; then
		ENTITY="service/set/deployment"
	else
		ENTITY="container"
	fi
	appname=$1
	url=$2
	echo -ne " Container $BOLD${appname}$EBOLD starting${SAMELINE}"


	pa_st=false
	echo -ne " Waiting for ${ENTITY} ${appname} service status...${SAMELINE}"
	TSTART=$SECONDS
	loop_ctr=0
	while (( $TSTART+600 > $SECONDS )); do
		result="$(__do_curl -m 10 $url)"
		if [ $? -eq 0 ]; then
			if [ ${#result} -gt 15 ]; then
				#If response is too long, truncate
				result="...response text too long, omitted"
			fi
			echo -ne " Waiting for {ENTITY} $BOLD${appname}$EBOLD service status on ${3}, result: $result${SAMELINE}"
	   		echo -ne " The ${ENTITY} $BOLD${appname}$EBOLD$GREEN is alive$EGREEN, responds to service status:$GREEN $result $EGREEN on ${url} after $(($SECONDS-$TSTART)) seconds"
	   		pa_st=true
	   		break
	 	else
		 	TS_TMP=$SECONDS
			TS_OFFSET=$loop_ctr
			if (( $TS_OFFSET > 5 )); then
				TS_OFFSET=5
			fi
			while [ $(($TS_TMP+$TS_OFFSET)) -gt $SECONDS ]; do
				echo -ne " Waiting for ${ENTITY} ${appname} service status on ${url}...$(($SECONDS-$TSTART)) seconds, retrying in $(($TS_TMP+$TS_OFFSET-$SECONDS)) seconds   ${SAMELINE}"
				sleep 1
			done
	 	fi
		let loop_ctr=loop_ctr+1
	done

	if [ "$pa_st" = "false"  ]; then
		((RES_CONF_FAIL++))
		echo -e $RED" The ${ENTITY} ${appname} did not respond to service status on ${url} in $(($SECONDS-$TSTART)) seconds"$ERED
		return 1
	fi

	echo ""
	return 0
}


#################
### Log functions
#################

__check_container_logs() {

	dispname=$1
	appname=$2
	logpath=$3
	warning=$4
	error=$5

	echo -e $BOLD"Checking $dispname container $appname log ($logpath) for WARNINGs and ERRORs"$EBOLD

	if [ $RUNMODE == "KUBE" ]; then
		echo -e $YELLOW" Internal log for $dispname not checked in kube"$EYELLOW
		return
	fi

	#tmp=$(docker ps | grep $appname)
	tmp=$(docker ps -q --filter name=$appname) #get the container id
	if [ -z "$tmp" ]; then  #Only check logs for running Policy Agent apps
		echo " "$dispname" is not running, no check made"
		return
	fi
	foundentries="$(docker exec -t $tmp grep $warning $logpath | wc -l)"
	if [ $? -ne  0 ];then
		echo "  Problem to search $appname log $logpath"
	else
		if [ $foundentries -eq 0 ]; then
			echo "  No WARN entries found in $appname log $logpath"
		else
			echo -e "  Found \033[1m"$foundentries"\033[0m WARN entries in $appname log $logpath"
		fi
	fi
	foundentries="$(docker exec -t $tmp grep $error $logpath | wc -l)"
	if [ $? -ne  0 ];then
		echo "  Problem to search $appname log $logpath"
	else
		if [ $foundentries -eq 0 ]; then
			echo "  No ERR entries found in $appname log $logpath"
		else
			echo -e $RED"  Found \033[1m"$foundentries"\033[0m"$RED" ERR entries in $appname log $logpath"$ERED
		fi
	fi
	echo ""
}

# Store all container logs and other logs in the log dir for the script
# Logs are stored with a prefix in case logs should be stored several times during a test
# args: <logfile-prefix>
# (Function for test scripts)
store_logs() {
	if [ $# != 1 ]; then
		((RES_CONF_FAIL++))
    	__print_err "need one arg, <file-prefix>" $@
		exit 1
	fi
	echo -e $BOLD"Storing all docker/kube container logs and other test logs in $TESTLOGS/$ATC using prefix: "$1$EBOLD

	docker stats --no-stream > $TESTLOGS/$ATC/$1_docker_stats.log 2>&1

	docker ps -a  > $TESTLOGS/$ATC/$1_docker_ps.log 2>&1

	cp .httplog_${ATC}.txt $TESTLOGS/$ATC/$1_httplog_${ATC}.txt 2>&1

	if [ $RUNMODE == "DOCKER" ]; then

		# Store docker logs for all container
		for imagename in $APP_SHORT_NAMES; do
			__check_included_image $imagename
			if [ $? -eq 0 ]; then
				# A function name is created from the app short name
				# for example app short name 'RICMSIM' -> produce the function
				# name __RICSIM__store_docker_logs
				# This function is called and is expected to exist in the imported
				# file for the ricsim test functions
				# The resulting function impl shall store the docker logs for each container
				function_pointer="__"$imagename"_store_docker_logs"
				$function_pointer "$TESTLOGS/$ATC/" $1
			fi
		done
	fi
	if [ $RUNMODE == "KUBE" ]; then
		namespaces=$(kubectl  get namespaces -o jsonpath='{.items[?(@.metadata.name)].metadata.name}')
		for nsid in $namespaces; do
			pods=$(kubectl get pods -n $nsid -o jsonpath='{.items[?(@.metadata.labels.autotest)].metadata.name}')
			for podid in $pods; do
				kubectl logs -n $nsid $podid > $TESTLOGS/$ATC/$1_${podid}.log
			done
		done
	fi
	echo ""
}

###############
## Generic curl
###############
# Generic curl function, assumes all 200-codes are ok
# args: <valid-curl-args-including full url>
# returns: <returned response (without respose code)>  or "<no-response-from-server>" or "<not found, <http-code>>""
# returns: The return code is 0 for ok and 1 for not ok
__do_curl() {
	echo ${FUNCNAME[1]} "line: "${BASH_LINENO[1]} >> $HTTPLOG
	proxyflag=""
	if [ $RUNMODE == "KUBE" ]; then
		if [ ! -z "$KUBE_PROXY_PATH" ]; then
			if [ $KUBE_PROXY_HTTPX == "http" ]; then
				proxyflag=" --proxy $KUBE_PROXY_PATH"
			else
				proxyflag=" --proxy-insecure --proxy $KUBE_PROXY_PATH"
			fi
		fi
	fi
	curlString="curl -skw %{http_code} $proxyflag $@"
	echo " CMD: $curlString" >> $HTTPLOG
	res=$($curlString)
	retcode=$?
	echo " RESP: $res" >> $HTTPLOG
	echo " RETCODE: $retcode" >> $HTTPLOG
	if [ $retcode -ne 0 ]; then
		echo "<no-response-from-server>"
		return 1
	fi
	http_code="${res:${#res}-3}"
	if [ ${#res} -eq 3 ]; then
		if [ $http_code -lt 200 ] || [ $http_code -gt 299 ]; then
			echo "<no-response-from-server>"
			return 1
		else
			return 0
		fi
	else
		if [ $http_code -lt 200 ] || [ $http_code -gt 299 ]; then
			echo "<not found, resp:${http_code}>"
			return 1
		fi
		if [ $# -eq 2 ]; then
  			echo "${res:0:${#res}-3}" | xargs
		else
  			echo "${res:0:${#res}-3}"
		fi

		return 0
	fi
}

#######################################
### Basic helper function for test cases
#######################################

# Test a simulator container variable value towards target value using an condition operator with an optional timeout.
# Arg: <simulator-name> <host> <variable-name> <condition-operator> <target-value>  - This test is done
# immediately and sets pass or fail depending on the result of comparing variable and target using the operator.
# Arg: <simulator-name> <host> <variable-name> <condition-operator> <target-value> <timeout>  - This test waits up to the timeout
# before setting pass or fail depending on the result of comparing variable and target using the operator.
# If the <variable-name> has the 'json:' prefix, the the variable will be used as url and the <target-value> will be compared towards the length of the json array in the response.
# Not to be called from test script.

__var_test() {
	checkjsonarraycount=0

	if [ $# -eq 6 ]; then
		if [[ $3 == "json:"* ]]; then
			checkjsonarraycount=1
		fi

		echo -e $BOLD"TEST $TEST_SEQUENCE_NR (${BASH_LINENO[1]}): ${1}, ${3} ${4} ${5} within ${6} seconds"$EBOLD
		((RES_TEST++))
		((TEST_SEQUENCE_NR++))
		start=$SECONDS
		ctr=0
		for (( ; ; )); do
			if [ $checkjsonarraycount -eq 0 ]; then
				result="$(__do_curl $2$3)"
				retcode=$?
				result=${result//[[:blank:]]/} #Strip blanks
			else
				path=${3:5}
				result="$(__do_curl $2$path)"
				retcode=$?
				echo "$result" > ./tmp/.tmp.curl.json
				result=$(python3 ../common/count_json_elements.py "./tmp/.tmp.curl.json")
			fi
			duration=$((SECONDS-start))
			echo -ne " Result=${result} after ${duration} seconds${SAMELINE}"
			let ctr=ctr+1
			if [ $retcode -ne 0 ]; then
				if [ $duration -gt $6 ]; then
					((RES_FAIL++))
					echo -e $RED" FAIL${ERED} - ${3} ${4} ${5} not reached in ${6} seconds, result = ${result}"
					__print_current_stats
					__check_stop_at_error
					return
				fi
			elif [ $4 = "=" ] && [ "$result" -eq $5 ]; then
				((RES_PASS++))
				echo -e " Result=${result} after ${duration} seconds${SAMELINE}"
				echo -e $GREEN" PASS${EGREEN} - Result=${result} after ${duration} seconds"
				__print_current_stats
				return
			elif [ $4 = ">" ] && [ "$result" -gt $5 ]; then
				((RES_PASS++))
				echo -e " Result=${result} after ${duration} seconds${SAMELINE}"
				echo -e $GREEN" PASS${EGREEN} - Result=${result} after ${duration} seconds"
				__print_current_stats
				return
			elif [ $4 = "<" ] && [ "$result" -lt $5 ]; then
				((RES_PASS++))
				echo -e " Result=${result} after ${duration} seconds${SAMELINE}"
				echo -e $GREEN" PASS${EGREEN} - Result=${result} after ${duration} seconds"
				__print_current_stats
				return
			elif [ $4 = "contain_str" ] && [[ $result =~ $5 ]]; then
				((RES_PASS++))
				echo -e " Result=${result} after ${duration} seconds${SAMELINE}"
				echo -e $GREEN" PASS${EGREEN} - Result=${result} after ${duration} seconds"
				__print_current_stats
				return
			else
				if [ $duration -gt $6 ]; then
					((RES_FAIL++))
					echo -e $RED" FAIL${ERED} - ${3} ${4} ${5} not reached in ${6} seconds, result = ${result}"
					__print_current_stats
					__check_stop_at_error
					return
				fi
			fi
			sleep 1
		done
	elif [ $# -eq 5 ]; then
		if [[ $3 == "json:"* ]]; then
			checkjsonarraycount=1
		fi

		echo -e $BOLD"TEST $TEST_SEQUENCE_NR (${BASH_LINENO[1]}): ${1}, ${3} ${4} ${5}"$EBOLD
		((RES_TEST++))
		((TEST_SEQUENCE_NR++))
		if [ $checkjsonarraycount -eq 0 ]; then
			result="$(__do_curl $2$3)"
			retcode=$?
			result=${result//[[:blank:]]/} #Strip blanks
		else
			path=${3:5}
			result="$(__do_curl $2$path)"
			retcode=$?
			echo "$result" > ./tmp/.tmp.curl.json
			result=$(python3 ../common/count_json_elements.py "./tmp/.tmp.curl.json")
		fi
		if [ $retcode -ne 0 ]; then
			((RES_FAIL++))
			echo -e $RED" FAIL ${ERED}- ${3} ${4} ${5} not reached, result = ${result}"
			__print_current_stats
			__check_stop_at_error
		elif [ $4 = "=" ] && [ "$result" -eq $5 ]; then
			((RES_PASS++))
			echo -e $GREEN" PASS${EGREEN} - Result=${result}"
			__print_current_stats
		elif [ $4 = ">" ] && [ "$result" -gt $5 ]; then
			((RES_PASS++))
			echo -e $GREEN" PASS${EGREEN} - Result=${result}"
			__print_current_stats
		elif [ $4 = "<" ] && [ "$result" -lt $5 ]; then
			((RES_PASS++))
			echo -e $GREEN" PASS${EGREEN} - Result=${result}"
			__print_current_stats
		elif [ $4 = "contain_str" ] && [[ $result =~ $5 ]]; then
			((RES_PASS++))
			echo -e $GREEN" PASS${EGREEN} - Result=${result}"
			__print_current_stats
		else
			((RES_FAIL++))
			echo -e $RED" FAIL${ERED} - ${3} ${4} ${5} not reached, result = ${result}"
			__print_current_stats
			__check_stop_at_error
		fi
	else
		echo "Wrong args to __var_test, needs five or six args: <simulator-name> <host> <variable-name> <condition-operator> <target-value> [ <timeout> ]"
		echo "Got:" $@
		exit 1
	fi
}
