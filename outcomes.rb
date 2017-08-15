require 'fastercsv'
require 'script/FUCHIA/utilities.rb'

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)

Utils = Utilities.new
User.current = User.first
Source_path = set_up_data['source_path']

HIV_STAGING = EncounterType.find_by_name('HIV STAGING')
HIV_CLINIC_CONSULTATION = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
HIV_STAGING_CONCEPT = ConceptName.find_by_name('Who stages criteria present').concept
Reason_for_starting_concept = ConceptName.find_by_name('REASON FOR ART ELIGIBILITY').concept

def start

   FasterCSV.foreach("#{Source_path}fuchia_ids.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|


       patient_id = PatientIdentifier.find_by_identifier(row['FUCHIA ID']).patient_id rescue nil

       next if patient_id.blank?
 
       hiv_staging_encounter = Encounter.find(:first, :conditions =>["patient_id = ? AND encounter_type = ?",
                                                                  patient_id, HIV_STAGING.id])
       next if hiv_staging_encounter.blank?

       reason_for_starting = get_reason_for_starting(row['Reason for Initiation'])
       start_date = row['Date of ARV Initiation']
       day = start_date.split("-")[0]
       month = Date::ABBR_MONTHNAMES.index(start_date.split("-")[1])
       year = start_date.split("-")[2]
       start_date = Utils.format_date("#{month}/#{day}/#{year}")
       puts ">>>>>>>#{patient_id}>>>>>>>>>>>>>>#{reason_for_starting}>>>>>>>>>>>>>>>#{start_date}>>>>>>>>>"

       obs = Observation.create(:person_id => patient_id, :encounter_id => hiv_staging_encounter.id,
                                :concept_id => Reason_for_starting_concept.id, :obs_datetime => hiv_staging_encounter.encounter_datetime,
                                :value_coded => ConceptName.find_by_name(reason_for_starting).concept_id,
                                :creator => User.current.id, :date_created => "#{hiv_staging_encounter.encounter_datetime}")

   end

end

  def get_reason_for_starting(fuchia_reason)
    reason = {
        "3"     => "WHO Stage 3",
        "4"     => "WHO stage 4",
        "BF"    => "Breastfeeding",
        "CD4"   => "CD4 COUNT LESS THAN OR EQUAL TO 250",
	      "PCR"   => "HIV PCR",
	      "Preg"  => "Patient pregnant",
        "PSHD"  => "PRESUMED SEVERE HIV CRITERIA IN INFANTS",
        "U5"    => "HIV Infected",
	      "UNK"   => "Unknown"
	    }

    return reason[fuchia_reason]
  end

start
