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

class DataCleaner

  def cleaner

    clean_patient_name_first_stage

    clean_patient_name_sec_stage

    clean_patient_name_third_stage

  end

  def clean_patient_name_first_stage

    patients = PersonName.find(:all, :conditions => ['family_name = ?','Unknown'])

    patients.each do |patient|

      middle_name = patient["middle_name"]

      patient_id = patient["person_name_id"]

      person = PersonName.find_by_person_name_id(patient_id)

      person.middle_name = ""

      person.family_name = middle_name

      person.save

      #sql_statement = 'UPDATE person_name SET family_name = "\#{middle_name}\" WHERE person_name_id = patient_id'

    end



  end


  def clean_patient_name_sec_stage

    patients = PersonName.all

    patients.each do |patient|

      family_name = patient["family_name"]

      middle_name = patient['middle_name']

      person_name_id = patient['person_name_id']

      person = PersonName.find(person_name_id)


      if (family_name.split(//).last(7).join == "Unknown")

        new_family_name = remove_unknown(family_name)

        if new_family_name.blank? && !middle_name.blank?

          person.middle_name = ''

          person.family_name = middle_name

          person.save

        else

          #update the name in the database now

          person.family_name = new_family_name

          person.save

        end

      end

    end

  end

  def clean_patient_name_third_stage

    patients = PersonName.all

    patients.each do |patient|

      family_name = patient['family_name']

      middle_name = patient['middle_name']

      person_name_id = patient['person_name_id']

      person = PersonName.find(person_name_id)

      if family_name.length.to_i <= 2 && !middle_name.blank?

        person.middle_name = ''

        person.family_name = middle_name

        person.save

      end

    end

  end

  def remove_unknown(name)

    return name if name.split(//).last(7).join != "Unknown"

    new_name = name[0..-8]

    remove_unknown(new_name)

  end

  def remove_encounters_without_observations

    encounters = Encounter.all

    encounters.each do |encounter|

      encounter_id = encounter.encounter_id

      observation = Observation.find_by_encounter_id(encounter_id)
      order = Order.find_by_encounter_id(encounter_id)

      if observation.blank? && order.blank?

        Encounter.find_by_encounter_id(encounter_id).destroy

      end

    end

  end

  def update_pregnancy_concept

    patients_with_pregnancy

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

  def update_breastfeed_concept

    FasterCSV.foreach("#{Source_path}tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      patient_id = row[3]
      breast_feed = row[39].to_i
      begin
        date_created = Utilities.new.format_date(row[1])
        visit_date = Utilities.new.format_date(row[9])
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

  def update_invalid_dates

    observations = Observation.find(:all, :conditions => ["obs_datetime ='0000-00-00 00:00:00'"])

    observations.each do |obs|

      encounter = Encounter.find_by_encounter_id(obs.encounter_id)

      ActiveRecord::Base.connection.execute <<EOF

        Update obs set obs_datetime = "#{encounter.encounter_datetime.to_time.strftime("%Y-%m-%d 00:00:00")}" where encounter_id = "#{obs.encounter_id}";
EOF


    end

  end

  def clean_patient_states

    $visit_date_and_state_array = []

    patient_programs = PatientProgram.all

    patient_programs.each do |patient_program|

      patient_program_id = patient_program['patient_program_id']

      patient_states = PatientState.find(:all, :conditions => ["patient_program_id = ?", patient_program_id])

      patient_states.each do |patient_state|

        $visit_date_and_state_array << [patient_state['patient_state_id'].to_i,patient_state['state'], patient_state['start_date']]

      end

      compare_states($visit_date_and_state_array)

    end

  end

  def compare_states(visits)

    i = 0

    while i < (visits.length - 1) do

      if visits[i][1] == visits[i+1][1]

        patient_state = PatientState.find_by_patient_state_id(visits[i+1][0])
        patient_state.destroy()
        visits.delete_at(i+1)
        compare_states(visits)
      else
        end_date = visits[i+1][2]
        patient_state = PatientState.find_by_patient_state_id(visits[i][0])
        patient_state.end_date = end_date.to_date.strftime("%Y-%m-%d 00:00:00")
        patient_state.save
        visits.delete_at(i)
        compare_states(visits)
      end

      i += 1

    end

  end

end

