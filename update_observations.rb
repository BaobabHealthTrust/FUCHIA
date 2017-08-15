require 'fastercsv'
require 'script/FUCHIA/utilities.rb'

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name'].split(" ")[0].downcase

Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/'

HIV_STAGING = EncounterType.find_by_name('HIV STAGING')
CLINIC_CONSULTATION = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
PREGNANCY_CONCEPT = ConceptName.find_by_name('Patient pregnant').concept
BREASTFEED_CONCEPT = ConceptName.find_by_name('Breastfeeding').concept
YES_CONCEPT = ConceptName.find_by_name('Yes').concept
NO_CONCEPT = ConceptName.find_by_name('No').concept
UNKNOWN_CONCEPT = ConceptName.find_by_name('Unknown').concept

@@patients_with_pregnant = []
@@patient_breastfeeding = {}

def start

  #updating patients pregnancy
  self.update_pregnancy_concept

  #Updating patients breastfeeding
  self.update_breastfeed_concept

end

def self.update_pregnancy_concept

  @@patients_with_pregnant.each do |patient_id|

    encounter = Encounter.find(:first, :conditions => ["patient_id = ? AND encounter_type = ?",
                                                       patient_id, HIV_STAGING.id])

    if !encounter.blank?

      puts "Updating pregnancy..................... #{patient_id}"

      observation = Observation.new
      observation.encounter_id = encounter.id
      observation.person_id = patient_id
      observation.concept_id = PREGNANCY_CONCEPT.id
      observation.value_coded = YES_CONCEPT.id
      observation.date_created = encounter.date_created
      observation.obs_datetime = encounter.encounter_datetime
      observation.creator = encounter.creator
      observation.save

    end

  end

end

def self.update_breastfeed_concept

  FasterCSV.foreach("#{Source_path}tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

    patient_id = row[3]
    breast_feed = row[39].to_i
    begin
      date_created = Utilities.new.get_proper_date(row[1])
      visit_date = Utilities.new.get_proper_date(row[9])
    rescue
      return
    end

    if breast_feed == 0
      value_coded = NO_CONCEPT.id
    elsif breast_feed == 2
      value_coded = YES_CONCEPT.id
    else
      value_coded = UNKNOWN_CONCEPT.id
    end

    encounter = Encounter.find(:first, :conditions => ["patient_id = ? AND encounter_datetime = ? and date_created = ?",
                                                       patient_id, visit_date, date_created])

    if !encounter.blank?

      puts "Updating breastfeeding..................... #{patient_id}"

      observation = Observation.new
      observation.encounter_id = encounter.id
      observation.person_id = patient_id
      observation.concept_id = BREASTFEED_CONCEPT.id
      observation.value_coded = value_coded
      observation.date_created = encounter.date_created
      observation.obs_datetime = encounter.encounter_datetime
      observation.creator = encounter.creator
      observation.save

    end

  end

end

def patients_with_pregnancy

  FasterCSV.foreach("#{Source_path}TbPatient.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

    patient_id = row[0]

    diagnosis = row[26]

    if diagnosis.match(/pregnan/i)

      @@patients_with_pregnant << patient_id

    end unless diagnosis.blank?

  end

end

patients_with_pregnancy

start
