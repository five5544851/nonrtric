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


TC_ONELINE_DESCR="ECS full interfaces walkthrough"

#App names to include in the test when running docker, space separated list
DOCKER_INCLUDED_IMAGES="ECS PRODSTUB CR RICSIM CP HTTPPROXY NGW"

#App names to include in the test when running kubernetes, space separated list
KUBE_INCLUDED_IMAGES="PRODSTUB CR ECS RICSIM CP HTTPPROXY KUBEPROXY NGW"
#Prestarted app (not started by script) to include in the test when running kubernetes, space separated list
KUBE_PRESTARTED_IMAGES=""

#Ignore image in DOCKER_INCLUDED_IMAGES, KUBE_INCLUDED_IMAGES if
#the image is not configured in the supplied env_file
#Used for images not applicable to all supported profile
CONDITIONALLY_IGNORED_IMAGES="NGW"

#Supported test environment profiles
SUPPORTED_PROFILES="ONAP-HONOLULU ONAP-ISTANBUL ORAN-CHERRY ORAN-D-RELEASE ORAN-E-RELEASE"
#Supported run modes
SUPPORTED_RUNMODES="DOCKER KUBE"

. ../common/testcase_common.sh  $@
. ../common/ecs_api_functions.sh
. ../common/prodstub_api_functions.sh
. ../common/cr_api_functions.sh
. ../common/control_panel_api_functions.sh
. ../common/controller_api_functions.sh
. ../common/ricsimulator_api_functions.sh
. ../common/http_proxy_api_functions.sh
. ../common/kube_proxy_api_functions.sh
. ../common/gateway_api_functions.sh

setup_testenvironment

#### TEST BEGIN ####

FLAT_A1_EI="1"

clean_environment

if [ $RUNMODE == "KUBE" ]; then
    start_kube_proxy
fi

use_ecs_rest_https

use_prod_stub_https

use_simulator_https

use_cr_https

start_http_proxy

start_ecs NOPROXY $SIM_GROUP/$ECS_COMPOSE_DIR/$ECS_CONFIG_FILE  #Change NOPROXY to PROXY to run with http proxy

if [ $RUNMODE == "KUBE" ]; then
    ecs_api_admin_reset
fi

start_prod_stub

set_ecs_debug

start_control_panel $SIM_GROUP/$CONTROL_PANEL_COMPOSE_DIR/$CONTROL_PANEL_CONFIG_FILE

if [ ! -z "$NRT_GATEWAY_APP_NAME" ]; then
    start_gateway $SIM_GROUP/$NRT_GATEWAY_COMPOSE_DIR/$NRT_GATEWAY_CONFIG_FILE
fi

if [ "$PMS_VERSION" == "V2" ]; then
    start_ric_simulators ricsim_g3 4  STD_2.0.0
fi

start_cr

CB_JOB="$PROD_STUB_SERVICE_PATH$PROD_STUB_JOB_CALLBACK"
CB_SV="$PROD_STUB_SERVICE_PATH$PROD_STUB_SUPERVISION_CALLBACK"
#Targets for ei jobs
TARGET1="$RIC_SIM_HTTPX://ricsim_g3_1:$RIC_SIM_PORT/datadelivery"
TARGET2="$RIC_SIM_HTTPX://ricsim_g3_2:$RIC_SIM_PORT/datadelivery"
TARGET3="$RIC_SIM_HTTPX://ricsim_g3_3:$RIC_SIM_PORT/datadelivery"
TARGET8="$RIC_SIM_HTTPX://ricsim_g3_4:$RIC_SIM_PORT/datadelivery"
TARGET10="$RIC_SIM_HTTPX://ricsim_g3_4:$RIC_SIM_PORT/datadelivery"

#Targets for info jobs
TARGET101="http://localhost:80/target"  # Dummy target, no target for info data in this env...
TARGET102="http://localhost:80/target"  # Dummy target, no target for info data in this env...
TARGET103="http://localhost:80/target"  # Dummy target, no target for info data in this env...
TARGET108="http://localhost:80/target"  # Dummy target, no target for info data in this env...
TARGET110="http://localhost:80/target"  # Dummy target, no target for info data in this env...
TARGET150="http://localhost:80/target"  # Dummy target, no target for info data in this env...
TARGET160="http://localhost:80/target"  # Dummy target, no target for info data in this env...

#Status callbacks for eijobs
STATUS1="$CR_SERVICE_PATH/job1-status"
STATUS2="$CR_SERVICE_PATH/job2-status"
STATUS3="$CR_SERVICE_PATH/job3-status"
STATUS8="$CR_SERVICE_PATH/job8-status"
STATUS10="$CR_SERVICE_PATH/job10-status"

#Status callbacks for infojobs
INFOSTATUS101="$CR_SERVICE_PATH/info-job101-status"
INFOSTATUS102="$CR_SERVICE_PATH/info-job102-status"
INFOSTATUS103="$CR_SERVICE_PATH/info-job103-status"
INFOSTATUS108="$CR_SERVICE_PATH/info-job108-status"
INFOSTATUS110="$CR_SERVICE_PATH/info-job110-status"
INFOSTATUS150="$CR_SERVICE_PATH/info-job150-status"
INFOSTATUS160="$CR_SERVICE_PATH/info-job160-status"

### Setup prodstub sim to accept calls for producers, types and jobs
## prod-a type1
## prod-b type1 and type2
## prod-c no-type
## prod-d type4
## prod-e type6
## prod-f type6

## job1 -> prod-a
## job2 -> prod-a
## job3 -> prod-b
## job4 -> prod-a
## job6 -> prod-b
## job8 -> prod-d
## job10 -> prod-e and prod-f

prodstub_arm_producer 200 prod-a
prodstub_arm_producer 200 prod-b
prodstub_arm_producer 200 prod-c
prodstub_arm_producer 200 prod-d
prodstub_arm_producer 200 prod-e
prodstub_arm_producer 200 prod-f

prodstub_arm_type 200 prod-a type1
prodstub_arm_type 200 prod-b type2
prodstub_arm_type 200 prod-b type3
prodstub_arm_type 200 prod-d type4
prodstub_arm_type 200 prod-e type6
prodstub_arm_type 200 prod-f type6

prodstub_disarm_type 200 prod-b type3
prodstub_arm_type 200 prod-b type1
prodstub_disarm_type 200 prod-b type1


prodstub_arm_job_create 200 prod-a job1
prodstub_arm_job_create 200 prod-a job2
prodstub_arm_job_create 200 prod-b job3

prodstub_arm_job_delete 200 prod-a job1
prodstub_arm_job_delete 200 prod-a job2
prodstub_arm_job_delete 200 prod-b job3

prodstub_arm_job_create 200 prod-b job4
prodstub_arm_job_create 200 prod-a job4

prodstub_arm_job_create 200 prod-b job6

prodstub_arm_job_create 200 prod-d job8

prodstub_arm_job_create 200 prod-e job10
prodstub_arm_job_create 200 prod-f job10

### ecs status
ecs_api_service_status 200

cr_equal received_callbacks 0

### Initial tests - no config made
### GET: type ids, types, producer ids, producers, job ids, jobs
### DELETE: jobs
ecs_api_a1_get_type_ids 200 EMPTY
ecs_api_a1_get_type 404 test-type

ecs_api_edp_get_type_ids 200 EMPTY
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_type 404 test-type
else
    ecs_api_edp_get_type_2 404 test-type
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 EMPTY
    ecs_api_edp_get_producer 404 test-prod
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE EMPTY
    ecs_api_edp_get_producer_2 404 test-prod
fi
ecs_api_edp_get_producer_status 404 test-prod

ecs_api_edp_delete_producer 404 test-prod

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_ids 404 test-type NOWNER
    ecs_api_a1_get_job_ids 404 test-type test-owner

    ecs_api_a1_get_job 404 test-type test-job

    ecs_api_a1_get_job_status 404 test-type test-job
else
    ecs_api_a1_get_job_ids 200 test-type NOWNER EMPTY
    ecs_api_a1_get_job_ids 200 test-type test-owner EMPTY

    ecs_api_a1_get_job 404 test-job

    ecs_api_a1_get_job_status 404 test-job
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_delete_job 404 test-type test-job
else
    ecs_api_a1_delete_job 404 test-job
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_jobs 404 test-prod
else
    ecs_api_edp_get_producer_jobs_2 404 test-prod
fi

if [ $ECS_VERSION == "V1-2" ]; then
    ecs_api_edp_get_type_2 404 test-type
    ecs_api_edp_delete_type_2 404 test-type
fi

### Setup of producer/job and testing apis ###

## Setup prod-a
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1 testdata/ecs/ei-type-1.json
    ecs_api_edp_put_producer 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1 testdata/ecs/ei-type-1.json
else
    #V1-2
    ecs_api_edp_get_type_ids 200 EMPTY
    ecs_api_edp_get_type_2 404 type1
    ecs_api_edp_put_producer_2 404 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1

    # Create type, delete and create again
    ecs_api_edp_put_type_2 201 type1 testdata/ecs/ei-type-1.json
    ecs_api_edp_get_type_2 200 type1
    ecs_api_edp_get_type_ids 200 type1
    ecs_api_edp_delete_type_2 204 type1
    ecs_api_edp_get_type_2 404 type1
    ecs_api_edp_get_type_ids 200 EMPTY
    ecs_api_edp_put_type_2 201 type1 testdata/ecs/ei-type-1.json
    ecs_api_edp_get_type_ids 200 type1
    ecs_api_edp_get_type_2 200 type1 testdata/ecs/ei-type-1.json

    ecs_api_edp_put_producer_2 201 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1
    ecs_api_edp_put_producer_2 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1
fi


ecs_api_a1_get_type_ids 200 type1
if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_type 200 type1 testdata/ecs/ei-type-1.json
else
    ecs_api_a1_get_type 200 type1 testdata/ecs/empty-type.json
fi

ecs_api_edp_get_type_ids 200 type1
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_type 200 type1 testdata/ecs/ei-type-1.json prod-a
else
    ecs_api_edp_get_type_2 200 type1 testdata/ecs/ei-type-1.json
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a
    ecs_api_edp_get_producer_ids_2 200 type1 prod-a
    ecs_api_edp_get_producer_ids_2 200 type2 EMPTY
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1 testdata/ecs/ei-type-1.json
else
    ecs_api_edp_get_producer_2 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1
fi

ecs_api_edp_get_producer_status 200 prod-a ENABLED

ecs_api_a1_get_job_ids 200 type1 NOWNER EMPTY
ecs_api_a1_get_job_ids 200 type1 test-owner EMPTY

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job 404 type1 test-job

    ecs_api_a1_get_job_status 404 type1 test-job
else
    ecs_api_a1_get_job 404 test-job

    ecs_api_a1_get_job_status 404 test-job
fi
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_jobs 200 prod-a EMPTY
else
    ecs_api_edp_get_producer_jobs_2 200 prod-a EMPTY
fi

## Create a job for prod-a
## job1 - prod-a
if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 201 type1 job1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json
else
    ecs_api_a1_put_job 201 job1 type1 $TARGET1 ricsim_g3_1 $STATUS1 testdata/ecs/job-template.json
fi

# Check the job data in the producer
if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json
    else
        prodstub_check_jobdata_3 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json
    fi
fi

ecs_api_a1_get_job_ids 200 type1 NOWNER job1
ecs_api_a1_get_job_ids 200 type1 ricsim_g3_1 job1

if [ ! -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job 200 type1 job1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json

    ecs_api_a1_get_job_status 200 type1 job1 ENABLED
else
    ecs_api_a1_get_job 200 job1 type1 $TARGET1 ricsim_g3_1 $STATUS1 testdata/ecs/job-template.json

    ecs_api_a1_get_job_status 200 job1 ENABLED
fi

prodstub_equal create/prod-a/job1 1

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_jobs 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json
else
    ecs_api_edp_get_producer_jobs_2 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json
fi

## Create a second job for prod-a
## job2 - prod-a
if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 201 type1 job2 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
else
    ecs_api_a1_put_job 201 job2 type1 $TARGET2 ricsim_g3_2 $STATUS2 testdata/ecs/job-template.json
fi

# Check the job data in the producer
if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-a job2 type1 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-a job2 type1 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
    else
        prodstub_check_jobdata_3 200 prod-a job2 type1 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
    fi
fi
ecs_api_a1_get_job_ids 200 type1 NOWNER job1 job2
ecs_api_a1_get_job_ids 200 type1 ricsim_g3_1 job1
ecs_api_a1_get_job_ids 200 type1 ricsim_g3_2 job2
if [ ! -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job 200 type1 job2 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json

    ecs_api_a1_get_job_status 200 type1 job2 ENABLED
else
    ecs_api_a1_get_job 200 job2 type1 $TARGET2 ricsim_g3_2 $STATUS2 testdata/ecs/job-template.json

    ecs_api_a1_get_job_status 200 job2 ENABLED
fi

prodstub_equal create/prod-a/job2 1

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_jobs 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json job2 type1 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
else
    ecs_api_edp_get_producer_jobs_2 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json job2 type1 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
fi

## Setup prod-b
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2 testdata/ecs/ei-type-2.json
else
    ecs_api_edp_put_type_2 201 type2 testdata/ecs/ei-type-2.json
    ecs_api_edp_put_producer_2 201 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2
fi


ecs_api_a1_get_type_ids 200 type1 type2
if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_type 200 type1 testdata/ecs/ei-type-1.json
    ecs_api_a1_get_type 200 type2 testdata/ecs/ei-type-2.json
else
    ecs_api_a1_get_type 200 type1 testdata/ecs/empty-type.json
    ecs_api_a1_get_type 200 type2 testdata/ecs/empty-type.json
fi

ecs_api_edp_get_type_ids 200 type1 type2
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_type 200 type1 testdata/ecs/ei-type-1.json prod-a
    ecs_api_edp_get_type 200 type2 testdata/ecs/ei-type-2.json prod-b
else
    ecs_api_edp_get_type_2 200 type1 testdata/ecs/ei-type-1.json
    ecs_api_edp_get_type_2 200 type2 testdata/ecs/ei-type-2.json
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1 testdata/ecs/ei-type-1.json
    ecs_api_edp_get_producer 200 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2 testdata/ecs/ei-type-2.json
else
    ecs_api_edp_get_producer_2 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1
    ecs_api_edp_get_producer_2 200 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2
fi

ecs_api_edp_get_producer_status 200 prod-b ENABLED

## Create job for prod-b
##  job3 - prod-b
if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 201 type2 job3 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json
else
    ecs_api_a1_put_job 201 job3 type2 $TARGET3 ricsim_g3_3 $STATUS3 testdata/ecs/job-template.json
fi

prodstub_equal create/prod-b/job3 1

# Check the job data in the producer
if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json
    else
        prodstub_check_jobdata_3 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json
    fi
fi

ecs_api_a1_get_job_ids 200 type1 NOWNER job1 job2
ecs_api_a1_get_job_ids 200 type2 NOWNER job3
ecs_api_a1_get_job_ids 200 type1 ricsim_g3_1 job1
ecs_api_a1_get_job_ids 200 type1 ricsim_g3_2 job2
ecs_api_a1_get_job_ids 200 type2 ricsim_g3_3 job3

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job 200 type2 job3 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json

    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
else
    ecs_api_a1_get_job 200 job3 type2 $TARGET3 ricsim_g3_3 $STATUS3 testdata/ecs/job-template.json

    ecs_api_a1_get_job_status 200 job3 ENABLED
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_jobs 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json job2 type1 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
    ecs_api_edp_get_producer_jobs 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json
else
    ecs_api_edp_get_producer_jobs_2 200 prod-a job1 type1 $TARGET1 ricsim_g3_1 testdata/ecs/job-template.json job2 type1 $TARGET2 ricsim_g3_2 testdata/ecs/job-template.json
    ecs_api_edp_get_producer_jobs_2 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json
fi

## Setup prod-c (no types)
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-c $CB_JOB/prod-c $CB_SV/prod-c NOTYPE
else
    ecs_api_edp_put_producer_2 201 prod-c $CB_JOB/prod-c $CB_SV/prod-c NOTYPE
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1 testdata/ecs/ei-type-1.json
    ecs_api_edp_get_producer 200 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2 testdata/ecs/ei-type-2.json
    ecs_api_edp_get_producer 200 prod-c $CB_JOB/prod-c $CB_SV/prod-c EMPTY
else
    ecs_api_edp_get_producer_2 200 prod-a $CB_JOB/prod-a $CB_SV/prod-a type1
    ecs_api_edp_get_producer_2 200 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2
    ecs_api_edp_get_producer_2 200 prod-c $CB_JOB/prod-c $CB_SV/prod-c EMPTY
fi

ecs_api_edp_get_producer_status 200 prod-c ENABLED


## Delete job3 and prod-b and re-create if different order

# Delete job then producer
ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2 job3
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_delete_job 204 type2 job3
else
    ecs_api_a1_delete_job 204 job3
fi

ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c
fi

ecs_api_edp_delete_producer 204 prod-b

ecs_api_edp_get_producer_status 404 prod-b

ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-c
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-c
fi

prodstub_equal delete/prod-b/job3 1

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 404 type2 job3 $TARGET3 ricsim_g3_3 testdata/ecs/job-template.json
else
    if [ $ECS_VERSION == "V1-1" ]; then
        ecs_api_a1_put_job 404 job3 type2 $TARGET3 ricsim_g3_3 $STATUS3 testdata/ecs/job-template.json
    else
        ecs_api_a1_put_job 201 job3 type2 $TARGET3 ricsim_g3_3 $STATUS3 testdata/ecs/job-template.json
        ecs_api_a1_get_job_status 200 job3 DISABLED
    fi
fi

# Put producer then job
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2 testdata/ecs/ei-type-2.json
else
    ecs_api_edp_put_producer_2 201 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2
fi

ecs_api_edp_get_producer_status 200 prod-b ENABLED

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 201 type2 job3 $TARGET3 ricsim_g3_3 testdata/ecs/job-template2.json
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
else
    if [ $ECS_VERSION == "V1-1" ]; then
        ecs_api_a1_put_job 201 job3 type2 $TARGET3 ricsim_g3_3 $STATUS3 testdata/ecs/job-template2.json
    else
        ecs_api_a1_put_job 200 job3 type2 $TARGET3 ricsim_g3_3 $STATUS3 testdata/ecs/job-template2.json
    fi
    ecs_api_a1_get_job_status 200 job3 ENABLED
fi

if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template2.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template2.json
    else
        prodstub_check_jobdata_3 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template2.json
    fi
fi

ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2 job3
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c
fi

if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_equal create/prod-b/job3 2
else
    prodstub_equal create/prod-b/job3 3
fi
prodstub_equal delete/prod-b/job3 1

# Delete only the producer
ecs_api_edp_delete_producer 204 prod-b

ecs_api_edp_get_producer_status 404 prod-b

ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2 job3
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-c
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-c
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type2 job3 DISABLED
else
    ecs_api_a1_get_job_status 200 job3 DISABLED
fi

cr_equal received_callbacks 1 30
cr_equal received_callbacks?id=job3-status 1
cr_api_check_all_ecs_events 200 job3-status DISABLED

# Re-create the producer
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2 testdata/ecs/ei-type-2.json
else
    ecs_api_edp_put_producer_2 201 prod-b $CB_JOB/prod-b $CB_SV/prod-b type2
fi

ecs_api_edp_get_producer_status 200 prod-b ENABLED

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
else
    ecs_api_a1_get_job_status 200 job3 ENABLED
fi

cr_equal received_callbacks 2 30
cr_equal received_callbacks?id=job3-status 2
cr_api_check_all_ecs_events 200 job3-status ENABLED

if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template2.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template2.json
    else
        prodstub_check_jobdata_3 200 prod-b job3 type2 $TARGET3 ricsim_g3_3 testdata/ecs/job-template2.json
    fi
fi

## Setup prod-d
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-d $CB_JOB/prod-d $CB_SV/prod-d type4 testdata/ecs/ei-type-4.json
else
    ecs_api_edp_put_type_2 201 type4 testdata/ecs/ei-type-1.json
    ecs_api_edp_put_producer_2 201 prod-d $CB_JOB/prod-d $CB_SV/prod-d type4
fi

ecs_api_a1_get_job_ids 200 type4 NOWNER EMPTY

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 201 type4 job8 $TARGET8 ricsim_g3_4 testdata/ecs/job-template.json
else
    ecs_api_a1_put_job 201 job8 type4 $TARGET8 ricsim_g3_4 $STATUS8 testdata/ecs/job-template.json
fi

if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-d job8 type4 $TARGET8 ricsim_g3_4 testdata/ecs/job-template.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-d job8 type4 $TARGET8 ricsim_g3_4 testdata/ecs/job-template.json
    else
        prodstub_check_jobdata_3 200 prod-d job8 type4 $TARGET8 ricsim_g3_4 testdata/ecs/job-template.json
    fi
fi

prodstub_equal create/prod-d/job8 1
prodstub_equal delete/prod-d/job8 0

ecs_api_a1_get_job_ids 200 type4 NOWNER job8

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
else
    ecs_api_a1_get_job_status 200 job8 ENABLED
fi

# Re-PUT the producer with zero types
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 200 prod-d $CB_JOB/prod-d $CB_SV/prod-d NOTYPE
else
    ecs_api_edp_put_producer_2 200 prod-d $CB_JOB/prod-d $CB_SV/prod-d NOTYPE
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_ids 404 type4 NOWNER
else
    ecs_api_a1_get_job_ids 200 type4 NOWNER job8
    ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2 job3 job8
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type4 job8 DISABLED
else
    ecs_api_a1_get_job_status 200 job8 DISABLED
fi

cr_equal received_callbacks 3 30
cr_equal received_callbacks?id=job8-status 1
cr_api_check_all_ecs_events 200 job8-status DISABLED

prodstub_equal create/prod-d/job8 1
prodstub_equal delete/prod-d/job8 0

## Re-setup prod-d
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 200 prod-d $CB_JOB/prod-d $CB_SV/prod-d type4 testdata/ecs/ei-type-4.json
else
    ecs_api_edp_put_type_2 200 type4 testdata/ecs/ei-type-4.json
    ecs_api_edp_put_producer_2 200 prod-d $CB_JOB/prod-d $CB_SV/prod-d type4
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_ids 404 type4 NOWNER
else
    ecs_api_a1_get_job_ids 200 type4 NOWNER job8
    ecs_api_a1_get_job_ids 200 NOTYPE NOWNER job1 job2 job3 job8
fi

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
else
    ecs_api_a1_get_job_status 200 job8 ENABLED
fi

ecs_api_edp_get_producer_status 200 prod-a ENABLED
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED

cr_equal received_callbacks 4 30
cr_equal received_callbacks?id=job8-status 2
cr_api_check_all_ecs_events 200 job8-status ENABLED

prodstub_equal create/prod-d/job8 2
prodstub_equal delete/prod-d/job8 0


## Setup prod-e
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-e $CB_JOB/prod-e $CB_SV/prod-e type6 testdata/ecs/ei-type-6.json
else
    ecs_api_edp_put_type_2 201 type6 testdata/ecs/ei-type-6.json
    ecs_api_edp_put_producer_2 201 prod-e $CB_JOB/prod-e $CB_SV/prod-e type6
fi

ecs_api_a1_get_job_ids 200 type6 NOWNER EMPTY

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 201 type6 job10 $TARGET10 ricsim_g3_4 testdata/ecs/job-template.json
else
    ecs_api_a1_put_job 201 job10 type6 $TARGET10 ricsim_g3_4 $STATUS10 testdata/ecs/job-template.json
fi

if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-e job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-e job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template.json
    else
        prodstub_check_jobdata_3 200 prod-e job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template.json
    fi
fi

prodstub_equal create/prod-e/job10 1
prodstub_equal delete/prod-e/job10 0

ecs_api_a1_get_job_ids 200 type6 NOWNER job10

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

## Setup prod-f
if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_put_producer 201 prod-f $CB_JOB/prod-f $CB_SV/prod-f type6 testdata/ecs/ei-type-6.json
else
    ecs_api_edp_put_type_2 200 type6 testdata/ecs/ei-type-6.json
    ecs_api_edp_put_producer_2 201 prod-f $CB_JOB/prod-f $CB_SV/prod-f type6
fi

ecs_api_a1_get_job_ids 200 type6 NOWNER job10

if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-f job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-f job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template.json
    else
        prodstub_check_jobdata_3 200 prod-f job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template.json
    fi
fi

prodstub_equal create/prod-f/job10 1
prodstub_equal delete/prod-f/job10 0

ecs_api_a1_get_job_ids 200 type6 NOWNER job10

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

## Status updates prod-a and jobs

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c prod-d prod-e prod-f
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c prod-d prod-e prod-f
fi

ecs_api_edp_get_producer_status 200 prod-a ENABLED
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED
ecs_api_edp_get_producer_status 200 prod-e ENABLED
ecs_api_edp_get_producer_status 200 prod-f ENABLED

# Arm producer prod-a for supervision failure
prodstub_arm_producer 200 prod-a 400

# Wait for producer prod-a to go disabled
ecs_api_edp_get_producer_status 200 prod-a DISABLED 360

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c prod-d  prod-e prod-f
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c prod-d  prod-e prod-f
fi

ecs_api_edp_get_producer_status 200 prod-a DISABLED
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED
ecs_api_edp_get_producer_status 200 prod-e ENABLED
ecs_api_edp_get_producer_status 200 prod-f ENABLED


if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type1 job1 ENABLED
    ecs_api_a1_get_job_status 200 type1 job2 ENABLED
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job1 ENABLED
    ecs_api_a1_get_job_status 200 job2 ENABLED
    ecs_api_a1_get_job_status 200 job3 ENABLED
    ecs_api_a1_get_job_status 200 job8 ENABLED
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

# Arm producer prod-a for supervision
prodstub_arm_producer 200 prod-a 200

# Wait for producer prod-a to go enabled
ecs_api_edp_get_producer_status 200 prod-a ENABLED 360

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c prod-d prod-e prod-f
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c prod-d prod-e prod-f
fi

ecs_api_edp_get_producer_status 200 prod-a ENABLED
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED
ecs_api_edp_get_producer_status 200 prod-e ENABLED
ecs_api_edp_get_producer_status 200 prod-f ENABLED

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type1 job1 ENABLED
    ecs_api_a1_get_job_status 200 type1 job2 ENABLED
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job1 ENABLED
    ecs_api_a1_get_job_status 200 job2 ENABLED
    ecs_api_a1_get_job_status 200 job3 ENABLED
    ecs_api_a1_get_job_status 200 job8 ENABLED
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

# Arm producer prod-a for supervision failure
prodstub_arm_producer 200 prod-a 400

# Wait for producer prod-a to go disabled
ecs_api_edp_get_producer_status 200 prod-a DISABLED 360

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-a prod-b prod-c prod-d prod-e prod-f
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-a prod-b prod-c prod-d prod-e prod-f
fi

ecs_api_edp_get_producer_status 200 prod-a DISABLED
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED
ecs_api_edp_get_producer_status 200 prod-e ENABLED
ecs_api_edp_get_producer_status 200 prod-f ENABLED

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type1 job1 ENABLED
    ecs_api_a1_get_job_status 200 type1 job2 ENABLED
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job1 ENABLED
    ecs_api_a1_get_job_status 200 job2 ENABLED
    ecs_api_a1_get_job_status 200 job3 ENABLED
    ecs_api_a1_get_job_status 200 job8 ENABLED
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

# Wait for producer prod-a to be removed
if [[ "$ECS_FEATURE_LEVEL" == *"INFO-TYPES"* ]]; then
    ecs_equal json:data-producer/v1/info-producers 5 1000
else
    ecs_equal json:ei-producer/v1/eiproducers 5 1000
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-b prod-c prod-d prod-e prod-f
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-b prod-c prod-d prod-e prod-f
fi


ecs_api_edp_get_producer_status 404 prod-a
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED
ecs_api_edp_get_producer_status 200 prod-e ENABLED
ecs_api_edp_get_producer_status 200 prod-f ENABLED

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type1 job1 DISABLED
    ecs_api_a1_get_job_status 200 type1 job2 DISABLED
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job1 DISABLED
    ecs_api_a1_get_job_status 200 job2 DISABLED
    ecs_api_a1_get_job_status 200 job3 ENABLED
    ecs_api_a1_get_job_status 200 job8 ENABLED
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

cr_equal received_callbacks 6 30
cr_equal received_callbacks?id=job1-status 1
cr_equal received_callbacks?id=job2-status 1

cr_api_check_all_ecs_events 200 job1-status DISABLED
cr_api_check_all_ecs_events 200 job2-status DISABLED


# Arm producer prod-e for supervision failure
prodstub_arm_producer 200 prod-e 400

ecs_api_edp_get_producer_status 200 prod-e DISABLED 1000

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-b prod-c prod-d prod-e prod-f
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-b prod-c prod-d prod-e prod-f
fi

ecs_api_edp_get_producer_status 404 prod-a
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED
ecs_api_edp_get_producer_status 200 prod-e DISABLED
ecs_api_edp_get_producer_status 200 prod-f ENABLED

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type1 job1 DISABLED
    ecs_api_a1_get_job_status 200 type1 job2 DISABLED
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job1 DISABLED
    ecs_api_a1_get_job_status 200 job2 DISABLED
    ecs_api_a1_get_job_status 200 job3 ENABLED
    ecs_api_a1_get_job_status 200 job8 ENABLED
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

#Disable create for job10 in prod-e
prodstub_arm_job_create 200 prod-e job10 400

#Update tjob 10 - only prod-f will be updated
if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_put_job 200 type6 job10 $TARGET10 ricsim_g3_4 testdata/ecs/job-template2.json
else
    ecs_api_a1_put_job 200 job10 type6 $TARGET10 ricsim_g3_4 $STATUS10 testdata/ecs/job-template2.json
fi
#Reset producer and job responses
prodstub_arm_producer 200 prod-e 200
prodstub_arm_job_create 200 prod-e job10 200

ecs_api_edp_get_producer_status 200 prod-e ENABLED 360

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-b prod-c prod-d prod-e prod-f
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-b prod-c prod-d prod-e prod-f
fi

#Wait for job to be updated
sleep_wait 120

if [ $ECS_VERSION == "V1-1" ]; then
    prodstub_check_jobdata 200 prod-f job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template2.json
else
    if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then
        prodstub_check_jobdata_2 200 prod-f job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template2.json
    else
        prodstub_check_jobdata_3 200 prod-f job10 type6 $TARGET10 ricsim_g3_4 testdata/ecs/job-template2.json
    fi
fi

prodstub_arm_producer 200 prod-f 400

ecs_api_edp_get_producer_status 200 prod-f DISABLED 360

if [[ "$ECS_FEATURE_LEVEL" == *"INFO-TYPES"* ]]; then
    ecs_equal json:data-producer/v1/info-producers 4 1000
else
    ecs_equal json:ei-producer/v1/eiproducers 4 1000
fi

if [ $ECS_VERSION == "V1-1" ]; then
    ecs_api_edp_get_producer_ids 200 prod-b prod-c prod-d prod-e
else
    ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-b prod-c prod-d prod-e
fi

ecs_api_edp_get_producer_status 404 prod-a
ecs_api_edp_get_producer_status 200 prod-b ENABLED
ecs_api_edp_get_producer_status 200 prod-c ENABLED
ecs_api_edp_get_producer_status 200 prod-d ENABLED
ecs_api_edp_get_producer_status 200 prod-e ENABLED
ecs_api_edp_get_producer_status 404 prod-f

if [  -z "$FLAT_A1_EI" ]; then
    ecs_api_a1_get_job_status 200 type1 job1 DISABLED
    ecs_api_a1_get_job_status 200 type1 job2 DISABLED
    ecs_api_a1_get_job_status 200 type2 job3 ENABLED
    ecs_api_a1_get_job_status 200 type4 job8 ENABLED
    ecs_api_a1_get_job_status 200 type6 job10 ENABLED
else
    ecs_api_a1_get_job_status 200 job1 DISABLED
    ecs_api_a1_get_job_status 200 job2 DISABLED
    ecs_api_a1_get_job_status 200 job3 ENABLED
    ecs_api_a1_get_job_status 200 job8 ENABLED
    ecs_api_a1_get_job_status 200 job10 ENABLED
fi

cr_equal received_callbacks 6


if [[ "$ECS_FEATURE_LEVEL" != *"INFO-TYPES"* ]]; then

    # End test if info types is not impl in tested version
    check_ecs_logs

    store_logs END

    #### TEST COMPLETE ####

    print_result

    auto_clean_environment
fi


############################################
# Test of info types
############################################

### Setup prodstub sim to accept calls for producers, info types and jobs
## prod-ia type101
## prod-ib type101 and type102
## prod-ic no-type
## prod-id type104
## prod-ie type106
## prod-if type106
## prod-ig type150  (configured later)
## prod-ig type160  (configured later)

## job101 -> prod-ia
## job102 -> prod-ia
## job103 -> prod-ib
## job104 -> prod-ia
## job106 -> prod-ib
## job108 -> prod-id
## job110 -> prod-ie and prod-if
## job150 -> prod-ig  (configured later)

prodstub_arm_producer 200 prod-ia
prodstub_arm_producer 200 prod-ib
prodstub_arm_producer 200 prod-ic
prodstub_arm_producer 200 prod-id
prodstub_arm_producer 200 prod-ie
prodstub_arm_producer 200 prod-if

prodstub_arm_type 200 prod-ia type101
prodstub_arm_type 200 prod-ib type102
prodstub_arm_type 200 prod-ib type103
prodstub_arm_type 200 prod-id type104
prodstub_arm_type 200 prod-ie type106
prodstub_arm_type 200 prod-if type106

prodstub_disarm_type 200 prod-ib type103
prodstub_arm_type 200 prod-ib type101
prodstub_disarm_type 200 prod-ib type101


prodstub_arm_job_create 200 prod-ia job101
prodstub_arm_job_create 200 prod-ia job102
prodstub_arm_job_create 200 prod-ib job103

prodstub_arm_job_delete 200 prod-ia job101
prodstub_arm_job_delete 200 prod-ia job102
prodstub_arm_job_delete 200 prod-ib job103

prodstub_arm_job_create 200 prod-ib job104
prodstub_arm_job_create 200 prod-ia job104

prodstub_arm_job_create 200 prod-ib job106

prodstub_arm_job_create 200 prod-id job108

prodstub_arm_job_create 200 prod-ie job110
prodstub_arm_job_create 200 prod-if job110


# NOTE: types, jobs and producers are still present related to eitypes


### Initial tests - no config made
### GET: type ids, types, producer ids, producers, job ids, jobs
### DELETE: jobs
ecs_api_idc_get_type_ids 200 type1 type2 type4 type6
ecs_api_idc_get_type 404 test-type

ecs_api_edp_get_type_ids 200 type1 type2 type4 type6
ecs_api_edp_get_type_2 404 test-type

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-b prod-c prod-d prod-e
ecs_api_edp_get_producer_2 404 test-prod
ecs_api_edp_get_producer_status 404 test-prod

ecs_api_edp_delete_producer 404 test-prod

ecs_api_idc_get_job_ids 200 test-type NOWNER EMPTY
ecs_api_idc_get_job_ids 200 test-type test-owner EMPTY

ecs_api_idc_get_job 404 test-job

ecs_api_idc_get_job_status2 404 test-job

ecs_api_idc_delete_job 404 test-job

ecs_api_edp_get_producer_jobs_2 404 test-prod

ecs_api_edp_get_type_2 404 test-type
ecs_api_edp_delete_type_2 404 test-type

### Setup of producer/job and testing apis ###

## Setup prod-ia
ecs_api_edp_get_type_ids 200 type1 type2 type4 type6
ecs_api_edp_get_type_2 404 type101
ecs_api_edp_put_producer_2 404 prod-ia $CB_JOB/prod-ia $CB_SV/prod-ia type101

# Create type, delete and create again
ecs_api_edp_put_type_2 201 type101 testdata/ecs/info-type-1.json
ecs_api_edp_get_type_2 200 type101
ecs_api_edp_get_type_ids 200 type101 type1 type2 type4 type6
ecs_api_edp_delete_type_2 204 type101
ecs_api_edp_get_type_2 404 type101
ecs_api_edp_get_type_ids 200 type1 type2 type4 type6
ecs_api_edp_put_type_2 201 type101 testdata/ecs/info-type-1.json
ecs_api_edp_get_type_ids 200 type101 type1 type2 type4 type6
ecs_api_edp_get_type_2 200 type101 testdata/ecs/info-type-1.json

ecs_api_edp_put_producer_2 201 prod-ia $CB_JOB/prod-ia $CB_SV/prod-ia type101
ecs_api_edp_put_producer_2 200 prod-ia $CB_JOB/prod-ia $CB_SV/prod-ia type101

ecs_api_edp_delete_type_2 406 type101


#ecs_api_idc_get_type_ids 200 type101
#ecs_api_idc_get_type 200 type101 testdata/ecs/empty-type.json

ecs_api_edp_get_type_ids 200 type101 type1 type2 type4 type6
ecs_api_edp_get_type_2 200 type101 testdata/ecs/info-type-1.json

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-b prod-c prod-d prod-e
ecs_api_edp_get_producer_ids_2 200 type101 prod-ia
ecs_api_edp_get_producer_ids_2 200 type102 EMPTY

ecs_api_edp_get_producer_2 200 prod-ia $CB_JOB/prod-ia $CB_SV/prod-ia type101

ecs_api_edp_get_producer_status 200 prod-ia ENABLED

ecs_api_idc_get_job_ids 200 type101 NOWNER EMPTY
ecs_api_idc_get_job_ids 200 type101 test-owner EMPTY

ecs_api_idc_get_job 404 test-job

ecs_api_idc_get_job_status2 404 test-job
ecs_api_edp_get_producer_jobs_2 200 prod-ia EMPTY

## Create a job for prod-ia
## job101 - prod-ia
ecs_api_idc_put_job 201 job101 type101 $TARGET101 info-owner-1 $INFOSTATUS101 testdata/ecs/job-template.json VALIDATE

# Check the job data in the producer
prodstub_check_jobdata_3 200 prod-ia job101 type101 $TARGET101 info-owner-1 testdata/ecs/job-template.json

ecs_api_idc_get_job_ids 200 type101 NOWNER job101
ecs_api_idc_get_job_ids 200 type101 info-owner-1 job101

ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job1 job2 job3 job8 job10

ecs_api_idc_get_job 200 job101 type101 $TARGET101 info-owner-1 $INFOSTATUS101 testdata/ecs/job-template.json

ecs_api_idc_get_job_status2 200 job101 ENABLED  1 prod-ia

prodstub_equal create/prod-ia/job101 1

ecs_api_edp_get_producer_jobs_2 200 prod-ia job101 type101 $TARGET101 info-owner-1 testdata/ecs/job-template.json

## Create a second job for prod-ia
## job102 - prod-ia
ecs_api_idc_put_job 201 job102 type101 $TARGET102 info-owner-2 $INFOSTATUS102 testdata/ecs/job-template.json  VALIDATE

# Check the job data in the producer
prodstub_check_jobdata_3 200 prod-ia job102 type101 $TARGET102 info-owner-2 testdata/ecs/job-template.json
ecs_api_idc_get_job_ids 200 type101 NOWNER job101 job102
ecs_api_idc_get_job_ids 200 type101 info-owner-1 job101
ecs_api_idc_get_job_ids 200 type101 info-owner-2 job102
ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job1 job2 job3 job8 job10

ecs_api_idc_get_job 200 job102 type101 $TARGET102 info-owner-2 $INFOSTATUS102 testdata/ecs/job-template.json

ecs_api_idc_get_job_status2 200 job102 ENABLED 1 prod-ia

prodstub_equal create/prod-ia/job102 1

ecs_api_edp_get_producer_jobs_2 200 prod-ia job101 type101 $TARGET101 info-owner-1 testdata/ecs/job-template.json job102 type101 $TARGET102 info-owner-2 testdata/ecs/job-template.json


## Setup prod-ib
ecs_api_edp_put_type_2 201 type102 testdata/ecs/info-type-2.json
ecs_api_edp_put_producer_2 201 prod-ib $CB_JOB/prod-ib $CB_SV/prod-ib type102


ecs_api_idc_get_type_ids 200 type101 type102 type1 type2 type4 type6

ecs_api_idc_get_type 200 type101 testdata/ecs/info-type-1.json

ecs_api_idc_get_type 200 type102 testdata/ecs/info-type-2.json

ecs_api_edp_get_type_ids 200 type101 type102 type1 type2 type4 type6
ecs_api_edp_get_type_2 200 type101 testdata/ecs/info-type-1.json
ecs_api_edp_get_type_2 200 type102 testdata/ecs/info-type-2.json

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_2 200 prod-ia $CB_JOB/prod-ia $CB_SV/prod-ia type101
ecs_api_edp_get_producer_2 200 prod-ib $CB_JOB/prod-ib $CB_SV/prod-ib type102

ecs_api_edp_get_producer_status 200 prod-ib ENABLED

## Create job for prod-ib
##  job103 - prod-ib
ecs_api_idc_put_job 201 job103 type102 $TARGET103 info-owner-3 $INFOSTATUS103 testdata/ecs/job-template.json  VALIDATE

prodstub_equal create/prod-ib/job103 1

# Check the job data in the producer
prodstub_check_jobdata_3 200 prod-ib job103 type102 $TARGET103 info-owner-3 testdata/ecs/job-template.json

ecs_api_idc_get_job_ids 200 type101 NOWNER job101 job102
ecs_api_idc_get_job_ids 200 type102 NOWNER job103
ecs_api_idc_get_job_ids 200 type101 info-owner-1 job101
ecs_api_idc_get_job_ids 200 type101 info-owner-2 job102
ecs_api_idc_get_job_ids 200 type102 info-owner-3 job103

ecs_api_idc_get_job 200 job103 type102 $TARGET103 info-owner-3 $INFOSTATUS103 testdata/ecs/job-template.json

ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib

ecs_api_edp_get_producer_jobs_2 200 prod-ia job101 type101 $TARGET101 info-owner-1 testdata/ecs/job-template.json job102 type101 $TARGET102 info-owner-2 testdata/ecs/job-template.json
ecs_api_edp_get_producer_jobs_2 200 prod-ib job103 type102 $TARGET103 info-owner-3 testdata/ecs/job-template.json

## Setup prod-ic (no types)
ecs_api_edp_put_producer_2 201 prod-ic $CB_JOB/prod-ic $CB_SV/prod-ic NOTYPE

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_2 200 prod-ia $CB_JOB/prod-ia $CB_SV/prod-ia type101
ecs_api_edp_get_producer_2 200 prod-ib $CB_JOB/prod-ib $CB_SV/prod-ib type102
ecs_api_edp_get_producer_2 200 prod-ic $CB_JOB/prod-ic $CB_SV/prod-ic EMPTY

ecs_api_edp_get_producer_status 200 prod-ic ENABLED


## Delete job103 and prod-ib and re-create if different order

# Delete job then producer
ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job103 job1 job2 job3 job8 job10
ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-b prod-c prod-d prod-e

ecs_api_idc_delete_job 204 job103

ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job1 job2 job3 job8 job10
ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-b prod-c prod-d prod-e

ecs_api_edp_delete_producer 204 prod-ib

ecs_api_edp_get_producer_status 404 prod-ib

ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job1 job2 job3 job8 job10
ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ic prod-b prod-c prod-d prod-e

prodstub_equal delete/prod-ib/job103 1

ecs_api_idc_put_job 201 job103 type102 $TARGET103 info-owner-3 $INFOSTATUS103 testdata/ecs/job-template.json VALIDATE
ecs_api_idc_get_job_status2 200 job103 DISABLED EMPTYPROD

# Put producer then job
ecs_api_edp_put_producer_2 201 prod-ib $CB_JOB/prod-ib $CB_SV/prod-ib type102

ecs_api_edp_get_producer_status 200 prod-ib ENABLED

ecs_api_idc_put_job 200 job103 type102 $TARGET103 info-owner-3 $INFOSTATUS103 testdata/ecs/job-template2.json  VALIDATE
ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib

prodstub_check_jobdata_3 200 prod-ib job103 type102 $TARGET103 info-owner-3 testdata/ecs/job-template2.json

ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job103 job1 job2 job3 job8 job10
ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-b prod-c prod-d prod-e

prodstub_equal create/prod-ib/job103 3
prodstub_equal delete/prod-ib/job103 1

# Delete only the producer
ecs_api_edp_delete_producer 204 prod-ib

ecs_api_edp_get_producer_status 404 prod-ib

ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job103  job1 job2 job3 job8 job10
ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ic prod-b prod-c prod-d prod-e

ecs_api_idc_get_job_status2 200 job103 DISABLED EMPTYPROD

cr_equal received_callbacks 7 30
cr_equal received_callbacks?id=info-job103-status 1
cr_api_check_all_ecs_events 200 info-job103-status DISABLED

# Re-create the producer
ecs_api_edp_put_producer_2 201 prod-ib $CB_JOB/prod-ib $CB_SV/prod-ib type102

ecs_api_edp_get_producer_status 200 prod-ib ENABLED

ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib

cr_equal received_callbacks 8 30
cr_equal received_callbacks?id=info-job103-status 2
cr_api_check_all_ecs_events 200 info-job103-status ENABLED

prodstub_check_jobdata_3 200 prod-ib job103 type102 $TARGET103 info-owner-3 testdata/ecs/job-template2.json

## Setup prod-id
ecs_api_edp_put_type_2 201 type104 testdata/ecs/info-type-4.json
ecs_api_edp_put_producer_2 201 prod-id $CB_JOB/prod-id $CB_SV/prod-id type104

ecs_api_idc_get_job_ids 200 type104 NOWNER EMPTY

ecs_api_idc_put_job 201 job108 type104 $TARGET108 info-owner-4 $INFOSTATUS108 testdata/ecs/job-template.json  VALIDATE

prodstub_check_jobdata_3 200 prod-id job108 type104 $TARGET108 info-owner-4 testdata/ecs/job-template.json

prodstub_equal create/prod-id/job108 1
prodstub_equal delete/prod-id/job108 0

ecs_api_idc_get_job_ids 200 type104 NOWNER job108

ecs_api_idc_get_job_status2 200 job108 ENABLED 1 prod-id

# Re-PUT the producer with zero types
ecs_api_edp_put_producer_2 200 prod-id $CB_JOB/prod-id $CB_SV/prod-id NOTYPE

ecs_api_idc_get_job_ids 200 type104 NOWNER job108
ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job103 job108  job1 job2 job3 job8 job10

ecs_api_idc_get_job_status2 200 job108 DISABLED EMPTYPROD

cr_equal received_callbacks 9 30
cr_equal received_callbacks?id=info-job108-status 1
cr_api_check_all_ecs_events 200 info-job108-status DISABLED

prodstub_equal create/prod-id/job108 1
prodstub_equal delete/prod-id/job108 0

## Re-setup prod-id
ecs_api_edp_put_type_2 200 type104 testdata/ecs/info-type-4.json
ecs_api_edp_put_producer_2 200 prod-id $CB_JOB/prod-id $CB_SV/prod-id type104

ecs_api_idc_get_job_ids 200 type104 NOWNER job108
ecs_api_idc_get_job_ids 200 NOTYPE NOWNER job101 job102 job103 job108 job1 job2 job3 job8 job10

ecs_api_idc_get_job_status2 200 job108 ENABLED  1 prod-id

ecs_api_edp_get_producer_status 200 prod-ia ENABLED
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED

cr_equal received_callbacks 10 30
cr_equal received_callbacks?id=info-job108-status 2
cr_api_check_all_ecs_events 200 info-job108-status ENABLED

prodstub_equal create/prod-id/job108 2
prodstub_equal delete/prod-id/job108 0


## Setup prod-ie
ecs_api_edp_put_type_2 201 type106 testdata/ecs/info-type-6.json
ecs_api_edp_put_producer_2 201 prod-ie $CB_JOB/prod-ie $CB_SV/prod-ie type106

ecs_api_idc_get_job_ids 200 type106 NOWNER EMPTY

ecs_api_idc_put_job 201 job110 type106 $TARGET110 info-owner-4 $INFOSTATUS110 testdata/ecs/job-template.json  VALIDATE

prodstub_check_jobdata_3 200 prod-ie job110 type106 $TARGET110 info-owner-4 testdata/ecs/job-template.json

prodstub_equal create/prod-ie/job110 1
prodstub_equal delete/prod-ie/job110 0

ecs_api_idc_get_job_ids 200 type106 NOWNER job110

ecs_api_idc_get_job_status2 200 job110 ENABLED 1 prod-ie

## Setup prod-if
ecs_api_edp_put_type_2 200 type106 testdata/ecs/info-type-6.json
ecs_api_edp_put_producer_2 201 prod-if $CB_JOB/prod-if $CB_SV/prod-if type106

ecs_api_idc_get_job_ids 200 type106 NOWNER job110

prodstub_check_jobdata_3 200 prod-if job110 type106 $TARGET110 info-owner-4 testdata/ecs/job-template.json

prodstub_equal create/prod-if/job110 1
prodstub_equal delete/prod-if/job110 0

ecs_api_idc_get_job_ids 200 type106 NOWNER job110

ecs_api_idc_get_job_status2 200 job110 ENABLED  2 prod-ie prod-if

## Status updates prod-ia and jobs

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-id prod-ie prod-if  prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_status 200 prod-ia ENABLED
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED
ecs_api_edp_get_producer_status 200 prod-ie ENABLED
ecs_api_edp_get_producer_status 200 prod-if ENABLED

# Arm producer prod-ia for supervision failure
prodstub_arm_producer 200 prod-ia 400

# Wait for producer prod-ia to go disabled
ecs_api_edp_get_producer_status 200 prod-ia DISABLED 360

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-id  prod-ie prod-if prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_status 200 prod-ia DISABLED
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED
ecs_api_edp_get_producer_status 200 prod-ie ENABLED
ecs_api_edp_get_producer_status 200 prod-if ENABLED


ecs_api_idc_get_job_status2 200 job101 ENABLED 1 prod-ia
ecs_api_idc_get_job_status2 200 job102 ENABLED 1 prod-ia
ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib
ecs_api_idc_get_job_status2 200 job108 ENABLED 1 prod-id
ecs_api_idc_get_job_status2 200 job110 ENABLED 2 prod-ie prod-if

# Arm producer prod-ia for supervision
prodstub_arm_producer 200 prod-ia 200

# Wait for producer prod-ia to go enabled
ecs_api_edp_get_producer_status 200 prod-ia ENABLED 360

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-id prod-ie prod-if prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_status 200 prod-ia ENABLED
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED
ecs_api_edp_get_producer_status 200 prod-ie ENABLED
ecs_api_edp_get_producer_status 200 prod-if ENABLED

ecs_api_idc_get_job_status2 200 job101 ENABLED 1 prod-ia
ecs_api_idc_get_job_status2 200 job102 ENABLED 1 prod-ia
ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib
ecs_api_idc_get_job_status2 200 job108 ENABLED 1 prod-id
ecs_api_idc_get_job_status2 200 job110 ENABLED 2 prod-ie prod-if

# Arm producer prod-ia for supervision failure
prodstub_arm_producer 200 prod-ia 400

# Wait for producer prod-ia to go disabled
ecs_api_edp_get_producer_status 200 prod-ia DISABLED 360

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ia prod-ib prod-ic prod-id prod-ie prod-if prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_status 200 prod-ia DISABLED
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED
ecs_api_edp_get_producer_status 200 prod-ie ENABLED
ecs_api_edp_get_producer_status 200 prod-if ENABLED

ecs_api_idc_get_job_status2 200 job101 ENABLED 1 prod-ia
ecs_api_idc_get_job_status2 200 job102 ENABLED 1 prod-ia
ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib
ecs_api_idc_get_job_status2 200 job108 ENABLED 1 prod-id
ecs_api_idc_get_job_status2 200 job110 ENABLED 2 prod-ie prod-if

# Wait for producer prod-ia to be removed
if [[ "$ECS_FEATURE_LEVEL" == *"INFO-TYPES"* ]]; then
    ecs_equal json:data-producer/v1/info-producers 9 1000
else
    ecs_equal json:ei-producer/v1/eiproducers 9 1000
fi

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ib prod-ic prod-id prod-ie prod-if  prod-b prod-c prod-d prod-e


ecs_api_edp_get_producer_status 404 prod-ia
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED
ecs_api_edp_get_producer_status 200 prod-ie ENABLED
ecs_api_edp_get_producer_status 200 prod-if ENABLED

ecs_api_idc_get_job_status2 200 job101 DISABLED EMPTYPROD
ecs_api_idc_get_job_status2 200 job102 DISABLED EMPTYPROD
ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib
ecs_api_idc_get_job_status2 200 job108 ENABLED 1 prod-id
ecs_api_idc_get_job_status2 200 job110 ENABLED 2 prod-ie prod-if

cr_equal received_callbacks 12 30
cr_equal received_callbacks?id=info-job101-status 1
cr_equal received_callbacks?id=info-job102-status 1

cr_api_check_all_ecs_events 200 info-job101-status DISABLED
cr_api_check_all_ecs_events 200 info-job102-status DISABLED


# Arm producer prod-ie for supervision failure
prodstub_arm_producer 200 prod-ie 400

ecs_api_edp_get_producer_status 200 prod-ie DISABLED 1000

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ib prod-ic prod-id prod-ie prod-if prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_status 404 prod-ia
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED
ecs_api_edp_get_producer_status 200 prod-ie DISABLED
ecs_api_edp_get_producer_status 200 prod-if ENABLED

ecs_api_idc_get_job_status2 200 job101 DISABLED EMPTYPROD
ecs_api_idc_get_job_status2 200 job102 DISABLED EMPTYPROD
ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib
ecs_api_idc_get_job_status2 200 job108 ENABLED 1 prod-id
ecs_api_idc_get_job_status2 200 job110 ENABLED 2 prod-ie prod-if

#Disable create for job110 in prod-ie
prodstub_arm_job_create 200 prod-ie job110 400

#Update tjob 10 - only prod-if will be updated
ecs_api_idc_put_job 200 job110 type106 $TARGET110 info-owner-4 $INFOSTATUS110 testdata/ecs/job-template2.json  VALIDATE
#Reset producer and job responses
prodstub_arm_producer 200 prod-ie 200
prodstub_arm_job_create 200 prod-ie job110 200

ecs_api_edp_get_producer_status 200 prod-ie ENABLED 360

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ib prod-ic prod-id prod-ie prod-if  prod-b prod-c prod-d prod-e

#Wait for job to be updated
sleep_wait 120

prodstub_check_jobdata_3 200 prod-if job110 type106 $TARGET110 info-owner-4 testdata/ecs/job-template2.json

prodstub_arm_producer 200 prod-if 400

ecs_api_edp_get_producer_status 200 prod-if DISABLED 360

if [[ "$ECS_FEATURE_LEVEL" == *"INFO-TYPES"* ]]; then
    ecs_equal json:data-producer/v1/info-producers 8 1000
else
    ecs_equal json:ei-producer/v1/eiproducers 8 1000
fi

ecs_api_edp_get_producer_ids_2 200 NOTYPE prod-ib prod-ic prod-id prod-ie prod-b prod-c prod-d prod-e

ecs_api_edp_get_producer_status 404 prod-ia
ecs_api_edp_get_producer_status 200 prod-ib ENABLED
ecs_api_edp_get_producer_status 200 prod-ic ENABLED
ecs_api_edp_get_producer_status 200 prod-id ENABLED
ecs_api_edp_get_producer_status 200 prod-ie ENABLED
ecs_api_edp_get_producer_status 404 prod-if

ecs_api_idc_get_job_status2 200 job101 DISABLED EMPTYPROD
ecs_api_idc_get_job_status2 200 job102 DISABLED EMPTYPROD
ecs_api_idc_get_job_status2 200 job103 ENABLED 1 prod-ib
ecs_api_idc_get_job_status2 200 job108 ENABLED 1 prod-id
ecs_api_idc_get_job_status2 200 job110 ENABLED 1 prod-ie

cr_equal received_callbacks 12

### Test of pre and post validation

ecs_api_idc_get_type_ids 200 type1 type2 type4 type6 type101 type102 type104 type106
ecs_api_idc_put_job 404 job150 type150 $TARGET150 info-owner-1 $INFOSTATUS150 testdata/ecs/job-template.json VALIDATE
ecs_api_idc_put_job 201 job160 type160 $TARGET160 info-owner-1 $INFOSTATUS160 testdata/ecs/job-template.json

ecs_api_idc_get_job_status2 404 job150
ecs_api_idc_get_job_status2 200 job160 DISABLED EMPTYPROD 60

prodstub_arm_producer 200 prod-ig
prodstub_arm_job_create 200 prod-ig job150
prodstub_arm_job_create 200 prod-ig job160

ecs_api_edp_put_producer_2 201 prod-ig $CB_JOB/prod-ig $CB_SV/prod-ig NOTYPE
ecs_api_edp_get_producer_status 200 prod-ig ENABLED 360

ecs_api_edp_get_producer_2 200 prod-ig $CB_JOB/prod-ig $CB_SV/prod-ig EMPTY

ecs_api_idc_get_job_status2 404 job150
ecs_api_idc_get_job_status2 200 job160 DISABLED EMPTYPROD 60

prodstub_arm_type 200 prod-ig type160

ecs_api_edp_put_type_2 201 type160 testdata/ecs/info-type-60.json
ecs_api_idc_get_type_ids 200 type1 type2 type4 type6 type101 type102 type104 type106 type160

ecs_api_edp_put_producer_2 200 prod-ig $CB_JOB/prod-ig $CB_SV/prod-ig type160
ecs_api_edp_get_producer_status 200 prod-ig ENABLED 360
ecs_api_edp_get_producer_2 200 prod-ig $CB_JOB/prod-ig $CB_SV/prod-ig type160

ecs_api_idc_put_job 404 job150 type150 $TARGET150 info-owner-1 $INFOSTATUS150 testdata/ecs/job-template.json VALIDATE

ecs_api_idc_get_job_status2 404 job150
ecs_api_idc_get_job_status2 200 job160 ENABLED 1 prod-ig 60

prodstub_check_jobdata_3 200 prod-ig job160 type160 $TARGET160 info-owner-1 testdata/ecs/job-template.json

prodstub_equal create/prod-ig/job160 1
prodstub_equal delete/prod-ig/job160 0

prodstub_arm_type 200 prod-ig type150

ecs_api_edp_put_type_2 201 type150 testdata/ecs/info-type-50.json
ecs_api_idc_get_type_ids 200 type1 type2 type4 type6 type101 type102 type104 type106 type160 type150

ecs_api_edp_put_producer_2 200 prod-ig $CB_JOB/prod-ig $CB_SV/prod-ig type160 type150
ecs_api_edp_get_producer_status 200 prod-ig ENABLED 360

ecs_api_edp_get_producer_2 200 prod-ig $CB_JOB/prod-ig $CB_SV/prod-ig type160 type150

ecs_api_idc_get_job_status2 404 job150
ecs_api_idc_get_job_status2 200 job160 ENABLED  1 prod-ig

ecs_api_idc_put_job 201 job150 type150 $TARGET150 info-owner-1 $INFOSTATUS150 testdata/ecs/job-template.json VALIDATE

ecs_api_idc_get_job_status2 200 job150 ENABLED  1 prod-ig 60
ecs_api_idc_get_job_status2 200 job160 ENABLED  1 prod-ig

cr_equal received_callbacks 12

check_ecs_logs

store_logs END

#### TEST COMPLETE ####

print_result

auto_clean_environment