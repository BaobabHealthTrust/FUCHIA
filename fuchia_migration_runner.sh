#!/usr/bin/env bash

echo "======== setup information ===========";
echo

ROOT=$(pwd)
SITE_NAME=$1
SOURCE_PATH=$2

echo "writing entries to the file..."

echo

cd config/

echo "{\"site_name\" : \"${SITE_NAME}\",\"source_path\" : \"${SOURCE_PATH}\"}" > setup_params.json

echo "Entries successfully saved!";

echo

SITE_NAME=$(echo $SITE_NAME| cut -d' ' -f 1)

[ -f $HOME/msf_\"${SITE_NAME}\" ] && echo "directory  found" || echo "directory not found...Creating the directory now...";  mkdir -p $HOME/msf_${SITE_NAME,,};

cd $HOME/msf_${SITE_NAME,,}/

echo "listing all files in the directory to verify the code is working...";

echo

ls -al

echo

echo "checking if sql dump files exist...";

[ -f patient_program.sql ] && rm patient_program.sql || echo "patient_program.sql does not exist...creating patient_program.sql now...";  touch patient_program.sql

echo

echo "======= Done creating patient_program.sql file=====";

echo

[ -f encounters.sql ] && rm encounters.sql || echo "encounters.sql does not exist...creating encounters.sql now...";  touch encounters.sql

echo

echo "======= Done creating encounters.sql file=====";

[ -f person.sql ] && rm person.sql || echo "person.sql does not exist...creating person.sql now...";  touch person.sql

echo

echo "======= Done creating person.sql file=====";

[ -f person_name.sql ] && rm person_name.sql || echo "person_name.sql does not exist...creating person_name.sql now...";  touch person_name.sql

echo

echo "======= Done creating person_name.sql file=====";

[ -f person_address.sql ] && rm person_address.sql || echo "person_address.sql does not exist...creating person_address.sql now...";  touch person_address.sql

echo

echo "======= Done creating person_address.sql file=====";

[ -f person_attribute.sql ] && rm person_attribute.sql || echo "person_attribute.sql does not exist...creating person_attribute.sql now...";  touch person_attribute.sql

echo

echo "======= Done creating person_attribute.sql file=====";

[ -f patient.sql ] && rm patient.sql || echo "patient.sql  does not exist...creating patient.sql now...";  touch patient.sql

echo

echo "======= Done creating patient.sql file=====";

[ -f observation.sql ] && rm observation.sql || echo "observation.sql  does not exist...creating observation.sql now...";  touch observation.sql

echo

echo "======= Done creating observation.sql file=====";

[ -f orders.sql ] && rm orders.sql || echo "orders.sql  does not exist...creating orders.sql now...";  touch orders.sql

echo

echo "======= Done creating orders.sql file=====";

[ -f drug_orders.sql ] && rm drug_orders.sql || echo "drug_orders.sql  does not exist...creating drug_orders.sql now...";  touch drug_orders.sql

echo

echo "======= Done creating drug_orders.sql file=====";

[ -f other_encounters.sql ] && rm other_encounters.sql || echo "other_encounters.sql  does not exist...creating other_encounters.sql now...";  touch other_encounters.sql

echo

echo "======= Done creating other_encounters.sql file=====";

[ -f other_obs.sql ] && rm other_obs.sql || echo "other_obs.sql  does not exist...creating other_obs.sql now...";  touch other_obs.sql

echo

echo "======= Done creating other_obs.sql file=====";

[ -f patient_state.sql ] && rm patient_state.sql || echo "patient_state.sql  does not exist...creating patient_state.sql now...";  touch patient_state.sql

echo

echo "======= Done creating patient_state.sql file=====";

[ -f reason_for_starting.sql ] && rm reason_for_starting.sql || echo "reason_for_starting.sql  does not exist...creating reason_for_starting.sql now...";  touch reason_for_starting.sql

echo

echo "======= Done creating reason_for_starting.sql file=====";

echo

echo "switching to migrations scripts...";

cd $ROOT

ls -al

echo "running the patient script......";

echo

script/runner  script/FUCHIA/patient.rb

echo

echo "=======Done running patient.rb script======= ";

echo

echo "running the encounters.rb... ";

echo

script/runner script/FUCHIA/encounters.rb

echo

echo "================Done running the encounters.rb script========";

echo

echo "Enrolling patient into ART programme....";

echo

script/runner script/FUCHIA/temp_script.rb

echo "===================Done enrolling patient into ART========================="

#echo "====================Done updating observations===============";
#
#echo

echo "Setting reasons for starting ARV.....";

echo

script/runner script/FUCHIA/outcomes.rb

echo

echo "=====================Done setting reason for eligibility===================";

echo

echo "Updating patient outcomes................";

script/runner script/FUCHIA/patient_outcomes.rb

echo

echo "===================Done updating patient outcomes============================";

echo"==================================== Done! ===================================="

#echo "running the set_reasons_for_starting script...";
#
#echo
#
#script/runner script/FUCHIA/set_reason_for_starting.rb
#
#echo
#
#echo "===================Done setting reasons for starting art=============";
#
#echo

#echo "========================== Done! =========================";
#
#echo

#echo "Setting patients pregnancy and breastfeeding"
#
#script/runner script/FUCHIA/set_pregnant_or_breastfeeding.rb
#
#echo "========================== Done! =========================";

echo