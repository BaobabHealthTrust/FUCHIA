#script to migrate arv numbers

require 'fastercsv'

Arv_number = PatientIdentifierType.find_by_name('ARV Number')
User.current = User.find_by_username('admin')
ScriptStared = Time.now()

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name'].split(' ')[0].downcase

Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #/home/pachawo/Documents/msf/msf_data/namitambo/


puts 'Provide arv number prefix (e.g NMDZ to get arv number with the following format NMDZ-ARV-23).'
Arv_number_prefix = $stdin.gets.chomp

def start

  counter = 1
  FasterCSV.foreach("#{Source_path}fuchia_ids.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

    arv_num = row['ARV NUMBER']
    order_date = row['orderdate']
    fuchia_id = row['FUCHIA ID']
    patient_id = PatientIdentifier.find_by_identifier(fuchia_id).patient_id rescue nil
    next if patient_id.blank?

    arv_number = "#{Arv_number_prefix.upcase}-ARV-#{counter}"
    arv_number = arv_num.blank? ? arv_number : arv_num

    puts "ARV Number for #{patient_id} is #{arv_number}"

    PatientIdentifier.create(:patient_id => patient_id,
                             :identifier => arv_number,
                             :identifier_type => Arv_number.id,
                             :creator => User.current.id)
    counter = counter + 1
  end
end

start