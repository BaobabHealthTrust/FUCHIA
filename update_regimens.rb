require 'fastercsv'
require 'script/FUCHIA/utilities.rb'

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

@@regimen_category = ConceptName.find_by_name('Regimen Category').concept
@@dispensing_encounter = EncounterType.find_by_name('DISPENSING')

User.current = User.find_by_username('admin')
Utils = Utilities.new
ScriptStarted = Time.now
Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/'

@@patient_fuchia_ids = Utils.get_fuchia_ids

@valid_regimens = ["0P","0A","2P","2A","4P","4A","5A", "6A","7A","8A","9P","9A","10A","11P","11A","12A"]

def start

  FasterCSV.foreach("#{Source_path}fuchia_ids.csv", :headers => true, :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
    moh_regimen = row["MOH Regimen"]
    fuchia_id = row["FUCHIA ID"]
    patient_id = PatientIdentifier.find_by_identifier(fuchia_id).patient_id rescue nil
    next if patient_id.blank? || moh_regimen.blank?

    regimen = moh_regimen.split(" ")[0]

    next unless @valid_regimens.include?regimen.upcase

    dispensing_encounter = Encounter.find(:last, :conditions =>["patient_id = ? AND encounter_type = ?",
                                                     patient_id,@@dispensing_encounter.id])
    next if dispensing_encounter.blank?

    regimen_obs = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id = ? AND concept_id = ?",
                  patient_id, dispensing_encounter.id, @@regimen_category.id])

    if regimen_obs.blank?

      Observation.create(:concept_id => @@regimen_category.id, :person_id => patient_id,
                         :value_text => regimen, :encounter_id => dispensing_encounter.id,
                         :obs_datetime => dispensing_encounter.encounter_datetime)
    else
      regimen_obs.update_attributes(:value_text => regimen)
    end

    puts "Regimen #{regimen} for #{patient_id}"
  end

end
start