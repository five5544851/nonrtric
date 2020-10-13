#!/usr/bin/env bash

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

TC_ONELINE_DESCR="Preparation demo setup  - populating a number of ric simulators with types and instances"

#App names to include in the test, space separated list
INCLUDED_IMAGES="CBS CONSUL CP CR MR PA RICSIM SDNC"

. ../common/testcase_common.sh $@
. ../common/agent_api_functions.sh
. ../common/ricsimulator_api_functions.sh

#### TEST BEGIN ####

#Local vars in test script
##########################
# Path to callback receiver
CR_PATH="http://$CR_APP_NAME:$CR_EXTERNAL_PORT/callbacks"
use_cr_http
use_agent_rest_http
use_sdnc_http
use_simulator_http

clean_containers

OSC_NUM_RICS=6
STD_NUM_RICS=5

start_ric_simulators  $RIC_SIM_PREFIX"_g1" $OSC_NUM_RICS OSC_2.1.0

start_ric_simulators  $RIC_SIM_PREFIX"_g2" $STD_NUM_RICS STD_1.1.3

start_mr #Just to prevent errors in the agent log...

start_control_panel

CR_PATH="https://$CR_APP_NAME:$CR_EXTERNAL_SECURE_PORT/callbacks"
use_cr_http

start_sdnc

start_consul_cbs

prepare_consul_config      SDNC  ".consul_config.json"
consul_config_app                  ".consul_config.json"

start_policy_agent

api_get_status 200

# Print the A1 version for OSC
for ((i=1; i<=$OSC_NUM_RICS; i++))
do
    sim_print $RIC_SIM_PREFIX"_g1_"$i interface
done


# Print the A1 version for STD
for ((i=1; i<=$STD_NUM_RICS; i++))
do
    sim_print $RIC_SIM_PREFIX"_g2_"$i interface
done


# Load the polictypes in osc
for ((i=1; i<=$OSC_NUM_RICS; i++))
do
    sim_put_policy_type 201 $RIC_SIM_PREFIX"_g1_"$i 100 demo-testdata/OSC/sim_qos.json
    sim_put_policy_type 201 $RIC_SIM_PREFIX"_g1_"$i 20008 demo-testdata/OSC/sim_tsa.json
done


#Check the number of schemas and the individual schemas in OSC
api_equal json:policy_types 3 120

for ((i=1; i<=$OSC_NUM_RICS; i++))
do
    api_equal json:policy_types?ric=$RIC_SIM_PREFIX"_g1_"$i 2 120
done

# Check the schemas in OSC
for ((i=1; i<=$OSC_NUM_RICS; i++))
do
    api_get_policy_schema 200 100 demo-testdata/OSC/qos-agent-modified.json
    api_get_policy_schema 200 20008 demo-testdata/OSC/tsa-agent-modified.json
done


# Create policies
use_agent_rest_http

api_put_service 201 "Emergency-response-app" 0 "$CR_PATH/1"

# Create policies in OSC
for ((i=1; i<=$OSC_NUM_RICS; i++))
do
    generate_uuid
    api_put_policy 201 "Emergency-response-app" $RIC_SIM_PREFIX"_g1_"$i 100 $((3000+$i)) NOTRANSIENT demo-testdata/OSC/piqos_template.json 1
    generate_uuid
    api_put_policy 201 "Emergency-response-app" $RIC_SIM_PREFIX"_g1_"$i 20008 $((4000+$i)) NOTRANSIENT demo-testdata/OSC/pitsa_template.json 1
done


# Check the number of policies in OSC
for ((i=1; i<=$OSC_NUM_RICS; i++))
do
    sim_equal $RIC_SIM_PREFIX"_g1_"$i num_instances 2
done


# Create policies in STD
for ((i=1; i<=$STD_NUM_RICS; i++))
do
    generate_uuid
    api_put_policy 201 "Emergency-response-app" $RIC_SIM_PREFIX"_g2_"$i NOTYPE $((2100+$i)) NOTRANSIENT demo-testdata/STD/pi1_template.json 1
done


# Check the number of policies in STD
for ((i=1; i<=$STD_NUM_RICS; i++))
do
    sim_equal $RIC_SIM_PREFIX"_g2_"$i num_instances 1
done

check_policy_agent_logs

#### TEST COMPLETE ####

store_logs          END

print_result