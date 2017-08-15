require 'fastercsv'
require 'script/FUCHIA/utilities.rb'
require 'script/FUCHIA/data_cleaner.rb'

User.current = User.find_by_username('admin')
ScriptStared = Time.now()
Utils = Utilities.new
Cleaner = DataCleaner.new
set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name'].downcase
Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/'

$db = YAML::load_file('config/database.yml')
$db_user = $db['development']['username']
$source_db = $db['development']['database']
$db_pass = $db['development']['password']
$db_host = $db['development']['host']

$visits = {}
$patient_drugs = {}
$dead_transfered_out_patients = {}
$references = Utils.set_references
$patient_drugs = Utils.drug_mapping
$dead_patients = Utils.get_dead_patients
$transfered_out_patients = Utils.get_transfered_out_patients


file_path = "#{Rails.root}/app/assets/data/errors/error.txt"

if !File.exists?(file_path)
  file = File.new(file_path, 'w')
end

def start

  drugs_map = $patient_drugs

  patient_prog_sql =  "INSERT INTO patient_program (patient_program_id,patient_id,program_id,"
  patient_prog_sql += "date_enrolled,date_completed,creator,date_created,changed_by,date_changed,"
  patient_prog_sql += "voided,voided_by,date_voided,void_reason,uuid,location_id) VALUES "

  patient_state_sql =   "INSERT INTO patient_state (patient_state_id,patient_program_id,state,"
  patient_state_sql +=  "start_date,end_date,creator,date_created, changed_by,date_changed,voided,"
  patient_state_sql +=  "voided_by, date_voided, void_reason,uuid) VALUES "

  encounter =  "INSERT INTO encounter (encounter_id,encounter_type,patient_id,provider_id,"
  encounter += "encounter_datetime,date_created,creator, uuid) VALUES "

  obs_sql =  "INSERT INTO obs (person_id, encounter_id, concept_id, value_numeric,value_coded,value_text,"
  obs_sql += "value_coded_name_id,value_datetime,value_drug, order_id, obs_datetime, creator, uuid) VALUES "



  `cd #{Destination_path} && [ -f patient_program.sql ] && rm patient_program.sql`
  `cd #{Destination_path} && [ -f patient_state.sql ] && rm patient_state.sql`
  `cd #{Destination_path} && [ -f other_encounters.sql ] && rm other_encounters.sql`
  `cd #{Destination_path} && [ -f other_obs.sql ] && rm other_obs.sql`


  `cd #{Destination_path} && touch drug_map.json patient_program.sql patient_state.sql other_encounters.sql other_obs.sql`
  
  File.open("#{Destination_path}drug_map.json", "w") {|hash| hash.write(drugs_map)}

  `echo -n '#{patient_state_sql}' >> #{Destination_path}patient_state.sql` 
  `echo -n '#{patient_prog_sql}' >> #{Destination_path}patient_program.sql`
  `echo -n '#{encounter}' >> #{Destination_path}other_encounters.sql`
  `echo -n '#{obs_sql}' >> #{Destination_path}other_obs.sql`


  patient_program = PatientProgram.last

  if patient_program.blank?

    patient_program_id = 1

  else 

    patient_program_id = patient_program.patient_program_id.to_i + 1

  end

  puts 'Enter the facility name: '
  location = gets.chomp
  location_id = Location.find_by_name(location).location_id rescue nil

  creator = User.current.id

  patient_state = PatientState.last

  if patient_state.blank?

    patient_state_counter = 1

  else

    patient_state_counter = patient_state.patient_state_id.to_i + 1

  end

  encounter_id =  1

  FasterCSV.foreach("#{Source_path}TbPatient.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

    patient_id = row[0]

    next unless patient_id == "741"

    #raise $visits[patient_id].inspect

    puts ".................................#{patient_id}.................................."

    begin 
      patient_visits_ids = $visits[patient_id]['visit_id']

      visit_dates = $visits[patient_id]['visit_date']

      date_enrolled = $visits[patient_id]['visit_date'].first.to_time.strftime("%Y-%m-%d 00:00:00")

    rescue

      File.open("#{Rails.root}/app/assets/data/errors/error.txt", 'a') do |f|
        f.puts "#{patient_id}>>>>>>>>>>>#{date_enrolled} \n"
      end

    end


    date_created = Utils.format_date(row[1])
    date_changed = Utils.format_date(row[2])

    data = {
        'patient_program_id' => patient_program_id,
        'date_enrolled' => "\"#{date_enrolled}\"",
        'date_completed' => 'NULL',
        'date_created' => "\"#{date_created}\"",
        'changed_by' => creator,
        'date_changed' => "\"#{date_changed}\"",
        'voided' => '0',
        'voided_by' => 'NULL',
        'date_voided' => 'NULL',
        'void_reason' => 'NULL',
        'location_id' => location_id,
        'creator' => creator
      }

    create_patient_program(data, patient_id)

    patient_state_id = patient_state_counter

    if !patient_visits_ids.blank?
    
    patient_visits_ids.each do |visit_id|

      index = patient_visits_ids.index(visit_id)

      visit_date = visit_dates[index].to_time.strftime("%Y-%m-%d 00:00:00")

      last_visit_date_index = (visit_dates.length - 1)

      end_date = visit_dates[last_visit_date_index].blank? ? 'NULL' : visit_dates[last_visit_date_index]


      patient_status_data = {
                           'patient_state_id' => patient_state_id,
                           'patient_program_id' => patient_program_id,
                           'start_date' => "\"#{visit_date}\"",
                           'end_date' => "\"#{end_date}\"",
                           'creator' => creator,
                           'date_created' => "\"#{date_created}\"",
                           'changed_by' => creator,
                           'date_changed' => "\"#{date_changed}\"",
                           'voided' => 0,
                           'voided_by' => 'NULL',
                           'date_voided' => 'NULL',
                           'void_reason' => 'NULL'
                  }


      puts visit_date.inspect

      drugs_dispensed = $patient_drugs[visit_id.to_i]

      if !drugs_dispensed.blank?

        concept_set_array = []
        medications = []
    
      begin

        drugs_dispensed.each do |medication|

          medication.each do |drug|

           puts  drug.inspect

            concept_id = Drug.find_by_name(drug).concept_id rescue nil

            drug_id = Drug.find_by_name(drug).drug_id rescue nil

            concept_set = ConceptSet.find_by_concept_id(concept_id).concept_set rescue nil

            concept_set_array << concept_set

            if concept_set == 1085

              medications << drug_id

            end

          end

        end

     rescue
      
	    File.open("#{Rails.root}/app/assets/data/errors/error.txt", 'a') do |f|
	     f.puts "#{patient_id}>>>>>>>>>>#{drugs_dispensed} \n"
	    end
     end

          if concept_set_array.include?1085

            create_patient_status(patient_status_data, 'On Antiretrovirals')

            puts " >>>>>>>>>>>>>> On art"

            puts medications.inspect
	          
            begin

	            treatment_encounter_id = EncounterType.find_by_name("TREATMENT").encounter_type_id
	    
	          rescue
	     
	            File.open("#{Rails.root}/app/assets/data/errors/error.txt", 'a') do |f|
	              f.puts "#{patient_id}>>>>>>>>>> \n"
	            end

  	        end 

            puts "#{patient_id} ############### #{treatment_encounter_id} ################### #{visit_date}"


            treatment_encounter = Encounter.find(:first, 
                  :conditions =>["patient_id = ? and encounter_type = ? and encounter_datetime = ?",patient_id,treatment_encounter_id,visit_date])
           
            value_text = MedicationService.regimen_interpreter(medications)

            type_of_art = ""

            medications.each do |drug_id|

              type_of_art += Drug.find_by_drug_id(drug_id).name rescue nil
              type_of_art += " "

            end

	          if !treatment_encounter.blank?
	      
              Utilities.new.create_observation_value_text(treatment_encounter,"What type of antiretroviral regimen",type_of_art, Destination_path + 'other_obs.sql')
              Utilities.new.create_observation_value_text(treatment_encounter,"Regimen Category", value_text, Destination_path + 'other_obs.sql')
	          
            end

          else

            if index == last_visit_date_index


              #check if patient is in the list of dead patients
              #if not found, the assumption is that the patient was transfered out

              if !$dead_patients[patient_id].blank?

                date_dead = $dead_patients[patient_id]

                #add to dead_transfered_out_patients hash

                $dead_transfered_out_patients[patient_id] = date_dead

                # Patient confirmed dead. Update the record in the database...
                puts "#{patient_id} >>>>>>>>>>>>>>>>Patient Confirmed dead on >>>>>>>>> #{$dead_patients[patient_id]}"


                create_patient_status(patient_status_data, 'Patient Died')

                exit_enc = create_exit_encounter(encounter_id,patient_id,'EXIT FROM HIV CARE',date_dead,patient_status_data['date_created'])

                encounter_id = encounter_id + 1

	        if !exit_enc.blank?

                  Utilities.new.create_observation_value_coded(exit_enc,'Reason for exiting care','Patient died',Destination_path + 'other_obs.sql')

                  Utilities.new.create_observation_value_datetime(exit_enc,'Date of exiting care',date_dead,Destination_path + 'other_obs.sql')

	  	end

              elsif !$transfered_out_patients[patient_id].blank?

                #Patient was Transfered out..


                puts "#{patient_id} >>>>>>>>>>>>>>>>>>>>>> Patient transfered out <<<<<<<<<<<<<<<<"

                create_patient_status(patient_status_data, 'Patient Transferred out')

                #add to dead_transfered_out_patients hash

                $dead_transfered_out_patients[patient_id] = visit_date

                exit_enc = create_exit_encounter(encounter_id,patient_id,'EXIT FROM HIV CARE',visit_date,patient_status_data['date_created'])

                encounter_id = encounter_id + 1

                Utilities.new.create_observation_value_coded(exit_enc,'Reason for exiting care','Patient transferred out',Destination_path + 'other_obs.sql')

                Utilities.new.create_observation_value_datetime(exit_enc,'Date of exiting care',visit_date,Destination_path + 'other_obs.sql')

              end

            else

              create_patient_status(patient_status_data, 'Pre-ART (Continue)')

              puts "Pre art??????????"

            end

          end



      else

        create_patient_status(patient_status_data, 'Pre-ART (Continue)')

        puts "Pre art!!!!!!!!!!!!"

      end

      patient_state_id = patient_state_id + 1


    end

    end

    patient_state_counter = patient_state_id

    patient_program_id = patient_program_id + 1

  end

  #Closing sql statement with a semicolon
  puts "..............please wait..................."

  patient_program_file_path = "#{Destination_path}patient_program.sql"
  patient_state_file_path = "#{Destination_path}patient_state.sql"
  other_encounter_path = "#{Destination_path}other_encounters.sql"
  other_obs_path = "#{Destination_path}other_obs.sql"

  Utilities.new.close_sql_with_semi_colon(patient_program_file_path)
  Utilities.new.close_sql_with_semi_colon(patient_state_file_path)
  Utilities.new.close_sql_with_semi_colon(other_encounter_path)
  Utilities.new.close_sql_with_semi_colon(other_obs_path)


  #Update ptient program
  puts "....................updating patient program...................."

  update_patient_program()

  puts "Loading patient programs...................................."

  `mysql -u '#{$db_user}' -p#{$db_pass} -h #{$db_host} '#{$source_db}' < '#{patient_program_file_path}'`

  puts "Loading patient state..............................."

  `mysql -u '#{$db_user}' -p#{$db_pass} -h #{$db_host} '#{$source_db}' < '#{patient_state_file_path}'`

  puts "Loading encounters............................"

  `mysql -u '#{$db_user}' -p#{$db_pass} -h #{$db_host} '#{$source_db}' < '#{other_encounter_path}'`
  
  puts "Loading observations............................"

  `mysql -u '#{$db_user}' -p#{$db_pass} -h #{$db_host} '#{$source_db}' < '#{other_obs_path}'`

  puts "Cleaning patient states........................"
  
  Cleaner.clean_patient_states

end

def create_patient_program(program_data, patient_id)

  program = Program.find_by_name('HIV PROGRAM')

  program_id = program.program_id


  uuid = ActiveRecord::Base.connection.select_one <<EOF

    select uuid();

EOF

  sql_statement =   "(#{program_data['patient_program_id']},#{patient_id},#{program_id},"
  sql_statement +=  "#{program_data['date_enrolled']},#{program_data['date_completed']},"
  sql_statement +=  "#{program_data['creator']},#{program_data['date_created']},#{program_data['changed_by']},"
  sql_statement +=  "#{program_data['date_changed']},#{program_data['voided']},#{program_data['voided_by']},"
  sql_statement +=  "#{program_data['date_voided']},#{program_data['void_reason']},\"#{uuid.values.first}\","
  sql_statement +=  "#{program_data['location_id']}),"

 `echo -n '#{sql_statement}' >> #{Destination_path}patient_program.sql`

end


def create_patient_status(patient_status, patient_state)

  concept_id = ConceptName.find_by_name(patient_state).concept_id rescue nil

  state = ProgramWorkflowState.find_by_concept_id(concept_id).program_workflow_state_id rescue nil

  uuid = ActiveRecord::Base.connection.select_one <<EOF

    select uuid();
EOF

 sql_statement = "(#{patient_status['patient_state_id']},#{patient_status['patient_program_id']},"
 sql_statement += "#{state},#{patient_status['start_date']},#{patient_status['end_date']},"
 sql_statement += "#{patient_status['creator']},#{patient_status['date_created']},#{patient_status['changed_by']},"
 sql_statement += "#{patient_status['date_changed']},#{patient_status['voided']},#{patient_status['voided_by']},"
 sql_statement += "#{patient_status['date_voided']},#{patient_status['void_reason']},\"#{uuid.values.first}\"),"

 `echo -n '#{sql_statement}' >> #{Destination_path}patient_state.sql`




end


def patient_visits
  #creating patient visits hash

  FasterCSV.foreach("#{Source_path}tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

    patient_id = row[3]

    if $visits[patient_id].blank?

      $visits[patient_id] = {'visit_date' => [], 'visit_id' => []}

    end

    $visits[patient_id]['visit_date'] << Utils.format_date(row[9])
    $visits[patient_id]['visit_id'] << row[0]

  end

end

def patient_drugs
  #creating patient drugs hash

  FasterCSV.foreach("#{Source_path}TbFollowUpDrug.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

    follow_up_id = row[3]

    if $patient_drugs[follow_up_id].blank?

      $patient_drugs[follow_up_id] = []

    end

    $patient_drugs[follow_up_id] << $references[row[4].to_i]

  end

end

def update_patient_program

  if !$dead_transfered_out_patients.blank?

      $dead_transfered_out_patients.each do |patient_id, date|

        puts ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> #{date}"

        sql =   "UPDATE patient_program SET date_completed = \"#{date}\" "
        sql +=  "WHERE patient_id = #{patient_id};"

        `echo '#{sql}' >> #{Destination_path}patient_program.sql`

      end

    end

end


def create_exit_encounter(encounter_id, patient_id, encounter_type, visit_date, date_created)

  encounter_type_id = EncounterType.find_by_name(encounter_type).encounter_type_id

  if !patient_id.blank?

    encounter = Encounter.new

    encounter.id = encounter_id

    encounter.encounter_type = encounter_type_id

    encounter.patient_id = patient_id

    encounter.encounter_datetime = visit_date

    uuid = ActiveRecord::Base.connection.select_one <<EOF

      select uuid();
EOF

      visit_date =visit_date

      encounter.date_created = date_created

      insert_encounters = "(\"#{encounter_id}\",\"#{encounter_type_id}\",\"#{patient_id}\",\"#{User.current.id}\",\"#{visit_date}\","

      insert_encounters += "\"#{User.current.id}\",\"#{encounter.date_created.strftime("%Y-%m-%d 00:00:00")}\",\"#{uuid.values.first}\"),"

      `echo -n '#{insert_encounters}' >> #{Destination_path}other_encounters.sql`

    end

    return encounter

end


#patient_drugs
patient_visits

start
