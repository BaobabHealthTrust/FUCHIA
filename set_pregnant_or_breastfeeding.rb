require 'fastercsv'
User.current = User.first

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name'].split(" ")[0].downcase

Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/

# @@followup = "/home/mwatha/Desktop/Tuesday/tb_follow_up.csv"
# @@pregnant2 = "/home/mwatha/Desktop/Tuesday/TbPatient.csv"

HIV_STAGING = EncounterType.find_by_name('HIV Staging')
HIV_CLINICAL_CONSULTATION = EncounterType.find_by_name('HIV CLINIC CONSULTATION')

Patient_pregnant_concept = ConceptName.find_by_name('Patient pregnant').concept
Breastfeeding_concept = ConceptName.find_by_name('Breastfeeding').concept
YES_Concept = ConceptName.find_by_name('Yes').concept
Reason_for_starting_concept = ConceptName.find_by_name('REASON FOR ART ELIGIBILITY').concept


@@patients_data = []

def start
  FasterCSV.foreach("#{Source_path}tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    condition_one = row[30] ; condition_two = row[31]
    condition_three = row[39] ; pregnant = false ; breastfeeding = false

    begin
      if condition_one.match(/preg/i) || condition_two.match(/preg/i)
          pregnant = true
      end
    rescue
      pregnant = false
    end

    begin
      if condition_three.match(/2/i)
          breastfeeding = true
      end
    rescue
      breastfeeding = false
    end

    next if not pregnant and not breastfeeding
    @@patients_data << [row[3].to_i, pregnant, breastfeeding, get_proper_date(row[9])]
    puts ".... #{row[3]}"
  end

  pregnant2
  setObs
end

def setObs
  (@@patients_data || []).each do |data|

    patient_id = data[0] ; pregnant = data[1] ; breastfeeding = data[2]
    date = data[3].to_date  

    encounter = Encounter.find(:first, :conditions =>["patient_id = ? 
      AND encounter_datetime BETWEEN (? AND ?) AND encounter_type = ?",
      patient_id, date.strftime('%Y-%m-%d 00:00:00'),
      date.strftime('%Y-%m-%d 23:59:59'), HIV_STAGING.id])

    if encounter.blank?
      encounter = Encounter.find(:first, :conditions =>["patient_id = ? 
        AND encounter_datetime BETWEEN (? AND ?) AND encounter_type = ?",
        patient_id, date.strftime('%Y-%m-%d 00:00:00'),
        date.strftime('%Y-%m-%d 23:59:59'), HIV_CLINICAL_CONSULTATION.id])
    end

    if encounter.blank?
      encounter = Encounter.create(:encounter_type => HIV_STAGING.id, :patient_id => patient_id,
        :encounter_datetime => date.strftime('%Y-%m-%d 00:00:00'))
      
      if pregnant
        Observation.create(:person_id => patient_id, :obs_datetime => encounter.encounter_datetime,
          :concept_id => Reason_for_starting_concept.id, :value_coded => Patient_pregnant_concept.id) 
      else
        Observation.create(:person_id => patient_id, :obs_datetime => encounter.encounter_datetime,
          :concept_id => Reason_for_starting_concept.id, :value_coded => Breastfeeding_concept.id) 
      end
    end


    Observation.create(:person_id => patient_id, :obs_datetime => encounter.encounter_datetime,
      :concept_id => Patient_pregnant_concept.id, :value_coded => YES_Concept.id) if pregnant

    Observation.create(:person_id => patient_id, :obs_datetime => encounter.encounter_datetime,
      :concept_id => Patient_pregnant_concept.id, :value_coded => YES_Concept.id) if breastfeeding

    puts ">>>>>>>>>>>>>>>>> #{data[0]}, #{data[3]}"

  end

end

def pregnant2
  FasterCSV.foreach("#{Source_path}TbPatient.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

    condition_one = row[26] ; condition_two = row[27] ; pregnant = false

    begin
    if condition_one.match(/preg/i) || condition_two.match(/preg/)
        pregnant = true
    end
    rescue
      next
    end

    next unless pregnant
    @@patients_data << [ row[0].to_i, pregnant, false,  get_proper_date(get_visit_date(row[0])) ]
    puts "**** #{row[0]}"
    return true

  end

end

def get_visit_date(patient_id)
  FasterCSV.foreach("#{Source_path}tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    next unless row[3].to_i == patient_id.to_i
    return row[9]
  end
end



def get_proper_date(unfomatted_date)
  if !unfomatted_date.blank?
    unfomatted_date = unfomatted_date.split("/")
    year_of_birth = unfomatted_date[2].split(" ")
    year_of_birth = year_of_birth[0]
    current_year = Date.today.year.to_s
    if year_of_birth.to_i > current_year[-2..-1].to_i
      year = "19#{year_of_birth}"
    else
      year = "20#{year_of_birth}"
    end
    fomatted_date = "#{year}-#{unfomatted_date[0]}-#{unfomatted_date[1]}"
  else
    return nil
  end
end



start
