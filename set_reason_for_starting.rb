require 'script/FUCHIA/data_cleaner.rb'

User.current = User.first
ScriptStared = Time.now
set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name'].split(" ")[0].downcase
Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/'

$db = YAML::load_file('config/database.yml')
$db_user = $db['development']['username']
$source_db = $db['development']['database']
$db_pass = $db['development']['password']
$db_host = $db['development']['host']


def self.concept_set(concept_name)
  concept_id = ConceptName.find_by_name(concept_name).concept_id

  set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
  options = set.map{|item|next if item.concept.blank? ; [item.concept.concept_id, item.concept.fullname] }
  return options
end

@@who_stage_peds_i = self.concept_set('WHO STAGE I PEDS')
@@who_stage_peds_ii = self.concept_set('WHO STAGE II PEDS')
@@who_stage_peds_iii = self.concept_set('WHO STAGE III PEDS')
@@who_stage_peds_iv = self.concept_set('WHO STAGE IV PEDS')

@@who_stage_adults_i = self.concept_set('WHO STAGE I ADULT')
@@who_stage_adults_ii = self.concept_set('WHO STAGE II ADULT')
@@who_stage_adults_iii = self.concept_set('WHO STAGE III ADULT')
@@who_stage_adults_iv = self.concept_set('WHO STAGE IV ADULT')

HIV_STAGING = EncounterType.find_by_name('HIV STAGING')
HIV_CLINIC_CONSULTATION = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
HIV_STAGING_CONCEPT = ConceptName.find_by_name('Who stages criteria present').concept
Reason_for_starting_concept = ConceptName.find_by_name('REASON FOR ART ELIGIBILITY').concept

def start

=begin
  (@@who_stage_adults_iv || []).each do |concept_id, fullname |
    puts ">>>>>>>>>>> #{concept_id}  #{fullname}"
  end
=end
  file_path = "#{Destination_path}reason_for_starting.sql"
  if !File.exists?(file_path)
    file = File.new(file_path, 'w')
  end

  #deleting all file contents
  File.open(file_path, 'w') do |f|
    f.truncate(0)
  end

  File.open(file_path, 'a') do |f|
    sql = "INSERT INTO obs (person_id, encounter_id, concept_id, obs_datetime, "
    sql += "value_coded, creator, date_created,uuid) VALUES"
    f.puts sql
  end


  patients = Person.find(:all) #, :limit => 50)

  (patients || []).each_with_index do |p, i|
    age = self.age_when_starting(p.id)[0] rescue nil
    start_date = self.age_when_starting(p.id)[1].to_date rescue nil
    hiv_staging_encounter = Encounter.find(:first, :conditions =>["patient_id = ? AND encounter_type = ?",
                                                                  p.id, HIV_STAGING.id])

    next if hiv_staging_encounter.blank?

    unless age.blank?
      who_stage = self.who_stage(p.id, age)
      if who_stage.match(/WHO stage III/i) || who_stage.match(/WHO stage IV/i)
        reason_for_starting = who_stage
      else
        reason_for_starting = self.get_reason_for_Art_eligibility(p.id, age, start_date)
      end

      uniqUIID = ActiveRecord::Base.connection.select_one <<EOF
      select UUID() AS uiid;
EOF

      File.open(file_path, 'a') do |f|
        sql = "(#{p.id}, #{hiv_staging_encounter.id}, #{Reason_for_starting_concept.id},"
        sql += "'#{start_date.strftime('%Y-%m-%d 00:00:00')}', #{ConceptName.find_by_name(reason_for_starting).concept_id},"
        sql += "#{User.current.id},'#{Time.now().strftime('%Y-%m-%d %H:%M:%S')}','#{uniqUIID['uiid']}'),"
        f.puts sql
      end

      uniqUIID = ActiveRecord::Base.connection.select_one <<EOF
      select UUID() AS uiid;
EOF

      File.open(file_path, 'a') do |f|
        sql = "(#{p.id}, #{hiv_staging_encounter.id}, #{HIV_STAGING_CONCEPT.id},"
        sql += "'#{start_date.strftime('%Y-%m-%d 00:00:00')}',"
        sql += "#{ConceptName.find_by_name(who_stage).concept_id},"
        sql += "#{User.current.id}, '#{Time.now().strftime('%Y-%m-%d %H:%M:%S')}','#{uniqUIID['uiid']}'),"
        f.puts sql
      end

    else
      uniqUIID = ActiveRecord::Base.connection.select_one <<EOF
      select UUID() AS uiid;
EOF

      File.open(file_path, 'a') do |f|
        sql = "(#{p.id}, #{hiv_staging_encounter.id}, #{Reason_for_starting_concept.id},"
        sql += "'#{hiv_staging_encounter.encounter_datetime.strftime('%Y-%m-%d 00:00:00')}',"
        sql += "#{ConceptName.find_by_name('Unknown').concept_id},#{User.current.id},"
        sql += "'#{Time.now().strftime('%Y-%m-%d %H:%M:%S')}','#{uniqUIID['uiid']}'),"
        f.puts sql
      end

      puts ".... #{(i + 1)} of #{patients.count}"
    end

  end

  content = ''
  File.open(file_path, 'r+') do |f|
    content = f.read[0..-3]
  end

  File.open(file_path, 'w') do |f|
    f.puts "#{content};"
  end

  #################################################################################################
  puts "Loading set reasons for starting art.........................."

  reason_for_starting_file_path = "#{Destination_path}reason_for_starting.sql"

  `mysql -u '#{$db_user}' -p#{$db_pass} -h '#{$db_host}' '#{$source_db}' < '#{reason_for_starting_file_path}'`

  puts "Removing encounters without obs..............................."

  #DataCleaner.new.remove_encounters_without_observations

  puts "Script time: #{ScriptStared} - #{Time.now()}"

end

def self.age_when_starting(patient_id)
  arv_drugs_concepts = MedicationService.arv_drugs.map(&:concept_id)

  patient_ids_and_init_dates = ActiveRecord::Base.connection.select_one <<EOF
    SELECT obs.person_id, MIN(obs_datetime) init_date FROM obs
    INNER JOIN drug_order do ON do.order_id = obs.order_id
    WHERE drug_inventory_id IN(
      SELECT drug_id FROM drug WHERE concept_id IN(#{arv_drugs_concepts.join(',')})
    ) AND obs.person_id = #{patient_id}
    GROUP BY person_id;
EOF

  return if patient_ids_and_init_dates.blank?

  begin
    date_when_starting = patient_ids_and_init_dates['init_date'].to_date
    birthdate = Person.find_by_person_id(patient_id).birthdate
  rescue
    return
  end

  dob = ActiveRecord::Base.connection.select_one <<EOF
    SELECT timestampdiff(year, DATE('#{birthdate}'), DATE('#{date_when_starting}')) AS age;
EOF

  age = dob['age'].to_i rescue 'Unknown'
  return [age, date_when_starting.to_date]
end




#################################################

def self.who_stage(patient_id, age)
  encounter_ids = Encounter.find(:all, :conditions => ["patient_id = ? AND
    encounter_type = ?",patient_id, HIV_STAGING.id]).map(&:encounter_id)

  return 'Unknown' if encounter_ids.blank?

  conditions = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?
    AND encounter_id IN(?)", patient_id, HIV_STAGING_CONCEPT.id,
                                                      encounter_ids]).map(&:value_coded)

  #puts "Conditions:  #{conditions.join(',')}"

  if age > 14
    (@@who_stage_adults_iv || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage IV adult"
      end
    end

    (@@who_stage_adults_iii || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage III adult"
      end
    end

    (@@who_stage_adults_ii || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage II adult"
      end
    end

    (@@who_stage_adults_i || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage I adult"
      end
    end

    return 'WHO stage I adult'
  else
    (@@who_stage_peds_iv || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage IV peds"
      end
    end

    (@@who_stage_peds_iii || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage III peds"
      end
    end

    (@@who_stage_peds_ii || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage II peds"
      end
    end

    (@@who_stage_peds_i || []).each do |concept_id, fullname |
      if conditions.include?(concept_id)
        return "WHO stage I peds"
      end
    end

    return 'WHO stage I peds'
  end

end

def self.get_reason_for_Art_eligibility(patient_id, age, start_date)
  encounter_ids = Encounter.find(:all, :conditions => ["patient_id = ? AND
    encounter_type = ?",patient_id, HIV_STAGING.id]).map(&:encounter_id)

  return 'Unknown' if encounter_ids.blank?

  observations = Observation.find(:all, :conditions => ["person_id = ? AND encounter_id IN(?)",
                                                        patient_id, encounter_ids])

  encounter_ids = Encounter.find(:all, :conditions => ["patient_id = ? AND
    encounter_type = ?",patient_id, HIV_CLINIC_CONSULTATION.id]).map(&:encounter_id)

  Observation.find(:all, :conditions => ["person_id = ? AND encounter_id IN(?)",
                                         patient_id, encounter_ids]).each do |ob|
    observations = [] if observations.blank?
    observations << ob
  end


  reason = 'Unknown'

  (observations || []).each do |ob|

    if ob.to_s.match(/pregnant/i)
      reason = 'Patient pregnant'
    end

    if ob.to_s.match(/breastfeeding/i)
      reason = 'Breastfeeding' unless reason.match(/pregnant/i)
    end

    if ob.concept_id == 5497
      reason = 'CD4 count' if not reason.match(/pregnant/i) or not reason.match(/breastfeeding/i)
      if ob.value_numeric <= 250
        reason = 'CD4 count less than or equal to 250'
      elsif ob.value_numeric <= 350
        reason = 'CD4 count less than or equal to 350'
      elsif ob.value_numeric <= 500
        reason = 'CD4 count less than or equal to 500'
      elsif ob.value_numeric <= 750
        reason = 'CD4 count less than or equal to 750'
      end
    end

    if age < 14
    end

  end

  return 'Asymptomatic' if reason.blank? and start_date >= '2016-04-01'.to_date
  return reason
end

start
