require 'fastercsv'
require 'script/FUCHIA/utilities.rb'
require 'script/FUCHIA/data_cleaner.rb'

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name']
@@Location = Location.find_by_name(site_name)
site_name = site_name.split(" ")[0].downcase

User.current = User.find_by_username('admin')
Utils = Utilities.new
Cleaner = DataCleaner.new
ScriptStarted = Time.now
Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/'

@@patient_fuchia_ids = Utils.get_fuchia_ids

$db = YAML::load_file('config/database.yml')
$db_user = $db['development']['username']
$source_db = $db['development']['database']
$db_pass = $db['development']['password']
$db_host = $db['development']['host']



@@patient_ids = {}

def start
  #returns a hash of references
  references = Utils.set_references
  person_sql = "INSERT INTO person (person_id, birthdate, birthdate_estimated, dead, gender, death_date, date_created, creator, uuid) VALUES "
  patient_sql = "INSERT INTO patient (patient_id,creator,date_created) VALUES "
  person_name_sql = "INSERT INTO person_name (person_id,middle_name,given_name,family_name,creator,date_created,uuid) VALUES "
  person_address_sql = "INSERT INTO person_address (person_id, city_village, date_created, creator, uuid) VALUES "
  person_attribute_sql = "INSERT INTO person_attribute (person_id, value, date_created, person_attribute_type_id, creator, uuid) VALUES "
  person_identifier_sql = "INSERT INTO patient_identifier(patient_id,identifier,identifier_type,creator,date_created,location_id, uuid) VALUES "

  `cd #{Destination_path} && [ -f person.sql ] && rm person.sql && [ -f patient.sql ] && rm patient.sql && [ -f person_name.sql ] && rm person_name.sql && [ -f person_address.sql ] && rm person_address.sql && [ -f person_attribute.sql ] && rm person_attribute.sql && [ -f patient_identifier.sql ] && rm patient_identifier.sql`

  `cd #{Destination_path} && touch person.sql patient.sql person_name.sql person_address.sql person_attribute.sql patient_identifier.sql`
  `echo -n '#{person_sql}' >> #{Destination_path}person.sql`
  `echo -n '#{patient_sql}' >> #{Destination_path}patient.sql`
  `echo -n '#{person_name_sql}' >> #{Destination_path}person_name.sql`
  `echo -n '#{person_address_sql}' >>  #{Destination_path}person_address.sql`
  `echo -n '#{person_attribute_sql}' >> #{Destination_path}person_attribute.sql`
  `echo -n '#{person_identifier_sql}' >> #{Destination_path}patient_identifier.sql`

  person_id = Person.last.id.blank? ? 1 : Person.last.id.to_i + 1

  FasterCSV.foreach("#{Source_path}TbPatient.csv", :headers => true, :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|

    next unless @@patient_fuchia_ids.include?(row['FdsId'])
    
    identifier = row['FdsId']

    @@patient_ids[row["FdxReference"]] = person_id


    names = row[9].split(' ') rescue "Unnamed"

    given_name = nil ; middle_name = nil ; family_name = nil

    (names || []).each_with_index do |name, i|
      next if name.blank?
      n = name.titleize.squish
      n = n.gsub('*','Unknown')
      given_name = n if i == 0

      if i == 1 and names.length > 2
        middle_name = n
      else
        family_name = n if i == 1
      end

      family_name = n if i == 2

    end

    age_estimate = false
    gender = row[10].squish.to_i rescue 'Unknown'
    date_created = Utils.format_date(row[1])
    date_created = date_created.to_date.strftime("%Y-%m-%d 01:00:00") rescue Date.today.strftime("%Y-%m-%d 01:00:00")
    age_estimate_date_created = row[14]
    date_of_death = Utils.format_date(row[21]) unless row[21].blank?
    is_dead = row[20] rescue nil
    city_village = row[3] rescue nil
    occupation = row[4] rescue nil
    age = row[12]
    city_village = references[city_village]
    city_village = "Unknown" if city_village.blank?
    occupation = references[occupation]
    occupation = "Unknown" if occupation.blank?


    if row[11].blank?

      age_estimate = true
      if !age_estimate_date_created.blank? and !age.blank?
        age_estimate_date_created = Utils.format_date(age_estimate_date_created)
        dob = Date.new(age_estimate_date_created.to_date.year - age.to_i, 7, 1)
      else
        dob = "1900-01-01"
      end

    else
      dob = Utils.format_date(row[11])
    end

    unless gender == 'Unknown'
      gender = gender == 0 ? 'M' : 'F'
    end

    death_date = date_of_death.to_date unless date_of_death.blank?
    gender = gender unless gender == 'Unknown'

    uuid = ActiveRecord::Base.connection.select_one <<EOF
    select uuid();
EOF

    if death_date.blank?
      insert_person =   "(#{person_id}, \"#{dob.to_date}\",#{age_estimate}, #{is_dead}, \"#{gender}\""
      insert_person +=  ",null,\"#{date_created}\", #{User.current.id}, \"#{uuid.values.first}\"),"
    else
      insert_person =   "(#{person_id}, \"#{dob.to_date}\",#{age_estimate}, #{is_dead},\"#{gender}\",\"#{ date_of_death}\""
      insert_person +=  ",\"#{date_created}\", #{User.current.id},\"#{uuid.values.first}\"),"
    end

    puts ">>>Person #{person_id}"
    `echo -n '#{insert_person}' >> #{Destination_path}person.sql`

    insert_patient = "(#{person_id},#{User.current.id},\"#{date_created}\"),"
    puts ">>>Patient details for #{person_id}"
    `echo -n '#{insert_patient}' >> #{Destination_path}patient.sql`

    uuid = ActiveRecord::Base.connection.select_one <<EOF
    select uuid();
EOF

    insert_person_name = "(#{person_id},\"#{middle_name}\",\"#{given_name}\",\"#{family_name}\",#{User.current.id},\"#{date_created}\",\"#{uuid.values.first}\"),"
    puts ">>>Person name for #{person_id}"
    `echo -n '#{insert_person_name}' >>  #{Destination_path}person_name.sql`

    uuid = ActiveRecord::Base.connection.select_one <<EOF
            select uuid();
EOF
    insert_person_address = "(#{person_id},\"#{city_village}\", \"#{date_created}\", #{User.current.id}, \"#{uuid.values.first}\"),"
    puts ">>>Person address for #{person_id}"
    `echo -n '#{insert_person_address}' >> #{Destination_path}person_address.sql`

    uuid = ActiveRecord::Base.connection.select_one <<EOF
        select uuid();
EOF
    attr_type_id = PersonAttributeType.find_by_name("Occupation").id
    insert_person_attr = "(#{person_id}, \"#{occupation}\", \"#{date_created}\", \"#{attr_type_id}\", #{User.current.id}, \"#{uuid.values.first}\"),"
    puts ">>>Person attributes for #{person_id}"
    `echo -n '#{insert_person_attr}' >> #{Destination_path}person_attribute.sql`

    uuid = ActiveRecord::Base.connection.select_one <<EOF
        select uuid();
EOF

    identifier_type = PatientIdentifierType.find_by_name("FUCHIA ID")
    if identifier_type.blank?
      identifier_type = PatientIdentifierType.create(:name => "FUCHIA ID",
                                                 :description => "Identifier for patients migrated from fuchia systems",
                                                 :creator => User.current.id)
    end
    insert_p_identifier = "(#{person_id},\"#{identifier}\",#{identifier_type.id},#{User.current.id},\"#{date_created}\",\"#{@@Location.id}\",\"#{uuid.values.first}\"),"
    puts ">>>Person identifier #{identifier} for #{person_id}"
    `echo -n '#{insert_p_identifier}' >> #{Destination_path}patient_identifier.sql`
    person_id = person_id + 1
  end

  puts "...........Please wait..............."

  person_file_path = "#{Destination_path}person.sql"
  patient_file_path = "#{Destination_path}patient.sql"
  person_name_file_path = "#{Destination_path}person_name.sql"
  person_address_file_path = "#{Destination_path}person_address.sql"
  person_attribute_file_path = "#{Destination_path}person_attribute.sql"
  person_identifier_file_path = "#{Destination_path}patient_identifier.sql"

  Utils.close_sql_with_semi_colon(person_file_path)
  Utils.close_sql_with_semi_colon(patient_file_path)
  Utils.close_sql_with_semi_colon(person_name_file_path)
  Utils.close_sql_with_semi_colon(person_address_file_path)
  Utils.close_sql_with_semi_colon(person_attribute_file_path)
  Utils.close_sql_with_semi_colon(person_identifier_file_path)

  puts "Loading person...................................."

  `mysql -u '#{$db_user}' -p#{$db_pass} -h '#{$db_host}' '#{$source_db}' < '#{person_file_path}' --verbose`

  puts "Loading person name..............................."

  `mysql -u '#{$db_user}' -p#{$db_pass} -h '#{$db_host}' '#{$source_db}' < '#{person_name_file_path}' --verbose`

  puts "Loading person address............................"

  `mysql -u '#{$db_user}' -p#{$db_pass} -h '#{$db_host}' '#{$source_db}' < '#{person_address_file_path}' --verbose`

  puts "Loading person attributes........................."

  `mysql -u '#{$db_user}' -p#{$db_pass} -h '#{$db_host}' '#{$source_db}' < '#{person_attribute_file_path}' --verbose`

  puts "Loading patients.................................."

  `mysql -u '#{$db_user}' -p#{$db_pass} -h '#{$db_host}' '#{$source_db}' < '#{patient_file_path}' --verbose`

  puts "Loading patients identifier......................."

  `mysql -u '#{$db_user}' -p#{$db_pass} -h '#{$db_host}' '#{$source_db}' < '#{person_identifier_file_path}' --verbose`

  puts "Cleaning data .................................."

  Cleaner.cleaner
  File.open("#{Destination_path}p_id.yml","w") do |file|
    file.write @@patient_ids.to_yaml
  end 

  puts "Script time #{ScriptStarted} - #{Time.now}"

end

start
