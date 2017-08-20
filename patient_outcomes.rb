require 'fastercsv'
require 'script/FUCHIA/utilities.rb'
require 'script/FUCHIA/data_cleaner.rb'

HIV_STAGING = EncounterType.find_by_name("HIV STAGING")
HIV_CLINIC_CONSULT = EncounterType.find_by_name("HIV CLINIC CONSULTATION")
TBStatusConcept = ConceptName.find_by_name('TB Status').concept
Who_stages_criteria = ConceptName.find_by_name('Who stages criteria present').concept_id
Ptb_within_the_past_two_yrs_concept_id = ConceptName.find_by_name('Ptb within the past two years').concept_id
Eptb_concept_id = ConceptName.find_by_name('EXTRAPULMONARY TUBERCULOSIS (EPTB)').concept_id
Preg_at_initiation_concept_id = ConceptName.find_by_name('PREGNANT AT INITIATION?').concept_id
Yes = ConceptName.find_by_name('YES').concept_id

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name']
@@Location = Location.find_by_name(site_name)
site_name = site_name.split(" ")[0].downcase

User.current = User.find_by_username('admin')
Utils = Utilities.new
ScriptStarted = Time.now
Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo

@@patient_fuchia_ids = Utils.get_fuchia_ids

def start

  FasterCSV.foreach("#{Source_path}fuchia_ids.csv", :headers => true, :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|

    f_id = row["FUCHIA ID"]
    transfer_in_status = row["Transfer In Status"]
    gender = row["Gender"]
    age = row["Age at Initation"]
    age_group = row["Age Group at Initiation"]
    reason = row["Reason for Initiation"]
    tb_status = row["TB Status at Initation"]
    ks_status = row["KS Status at Initiation"]
    month_of_death = row["Month of Death after ARV start"]
    primary_outcome = row["Other Primary Outcomes"]
    outcome_date = row["Outcome Date"]
    start_date = row["Date of ARV Initiation"] rescue nil
    last_arv_treatment = row["Last ARV Treatment"]
    moh_regimen = row["MOH Regimen"]
    cur_preg = row["Current Preg Status"]
    cur_tb_status = row["Current TB Status"]
    side_effect = row["Side Effects"]
    adherence = row["Adherence (Pills Remaining)"]

    next if start_date.blank?

    day = start_date.split("-")[0]
    month = Date::ABBR_MONTHNAMES.index(start_date.split("-")[1])
    year = start_date.split("-")[2]
    date = Utils.format_date("#{month}/#{day}/#{year}")

    patient_id = PatientIdentifier.find_by_identifier("#{f_id}").patient_id rescue nil

    next if patient_id.blank?

    begin

      staging_encounter = Encounter.find(:first, :conditions => ["patient_id = ? and encounter_type = ?",
                                                                 patient_id, HIV_STAGING.id])

      consultation_encounter = Encounter.find(:last, :conditions => ["patient_id = ? and encounter_type = ?",
                                                                     patient_id, HIV_CLINIC_CONSULT.id])

      if staging_encounter.blank?
        staging_encounter = Encounter.create(:encounter_type => HIV_STAGING.id, :patient_id => patient_id,
                                             :encounter_datetime => date)
      else
        staging_encounter.update_attributes(:encounter_datetime => date)
      end

      ############## patient is pregnant on the initiation #######################

      if gender == "FP"
        puts "Patient #{patient_id} pregnant on initiation"
        Observation.create(:person_id => patient_id, :concept_id => Preg_at_initiation_concept_id, :encounter_id => staging_encounter.id,
                           :obs_datetime => date, :value_coded => Yes, :creator => User.current.id)
      end

      ##################### tb status on initiation ###################################

      unless tb_status.blank?
        if tb_status == "Last 2yrs"
          puts "Patient #{patient_id} had TB within the last 2 years on initiation"
          eptb_concept = Ptb_within_the_past_two_yrs_concept_id
        elsif tb_status == "Curr"
          puts "Patient #{patient_id} had TB on initiation"
          eptb_concept = Eptb_concept_id
        end

        Observation.create(:person_id => patient_id, :concept_id => Who_stages_criteria, :encounter_id => staging_encounter.id,
                           :obs_datetime => date, :value_coded => eptb_concept, :creator => User.current.id)
      end

      ##################### current tb/pregnant status ###################################

      unless consultation_encounter.blank?

        if cur_preg == "1"

          puts "Patient currently pregnant"
          Observation.create(:person_id => patient_id, :concept_id => ConceptName.find_by_name("Is patient pregnant?").concept_id,
                             :encounter_id => consultation_encounter.id, :obs_datetime => consultation_encounter.encounter_datetime,
                             :value_coded => Yes, :creator => User.current.id)
        end

      end

    rescue

      # log errors

    end

  end

end

start