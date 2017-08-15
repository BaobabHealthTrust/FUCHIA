require 'fastercsv'
require 'script/FUCHIA/utilities'

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name'].split(" ")[0].downcase
Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/'
Utils = Utilities.new

@@p_ids = YAML::load_file("#{Destination_path}p_id.yml")
@@visits = {}

`cd '#{Destination_path}' && touch visits.txt`

def start
  @@before_dates = {}
  FasterCSV.foreach("#{Source_path}fuchia_ids.csv", :headers => true, :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|
    f_id = row['FUCHIA ID']
    start_date = row['Date of ARV Initiation']
    day = start_date.split("-")[0]
    month = Date::ABBR_MONTHNAMES.index(start_date.split("-")[1])
    year = start_date.split("-")[2]
    init_date = Utils.format_date("#{month}/#{day}/#{year}") rescue nil
    next if @@visits[f_id].blank?

    @@visits[f_id].each do |visit_day|
      if visit_day < init_date
        puts "#{f_id}........#{visit_day}"
        if @@before_dates[f_id].blank?
          @@before_dates[f_id] = []
          @@before_dates[f_id] << "| #{init_date} "
        end
        @@before_dates[f_id] << "| #{visit_day} "
      end

    end
    `echo '#{@@before_dates}' >> #{Destination_path}visits.txt`
    @@before_dates = {}
  end

end

def visit
  FasterCSV.foreach("#{Source_path}tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
    patient_id = @@p_ids[row['FdxReferencePatient']]

    identifier = PatientIdentifier.find_by_patient_id(patient_id)

    next if identifier.blank?

    fuchia_id = identifier.identifier

    if @@visits[fuchia_id].blank?
      @@visits[fuchia_id] = []
    end
    @@visits[fuchia_id] << Utils.format_date(row['FddVisit'])
  end
end

visit
start
