require "fastercsv"
require 'script/FUCHIA/utilities.rb'


User.current = User.find_by_username('admin')
Utils = Utilities.new

set_up = File.read('config/setup_params.json')
set_up_data = JSON.parse(set_up)
site_name = set_up_data['site_name'].downcase
Source_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo

CurrentLocation = Location.find_by_name(site_name).inspect
IdType = PatientIdentifierType.find_by_name("FUCHIA ID")
Dispensing = EncounterType.find_by_name("Dispensing")

@@table = "#{Source_path}fuchia_ids.csv"
@@program = Program.find_by_name('HIV program')

#raise @@table.inspect

def start
  @counter = 1
  FasterCSV.foreach(@@table, :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|


      start_date = row["Date of ARV Initiation"] rescue nil
      identifier = row["FUCHIA ID"]
      patient_died = row["Month of Death after ARV start"]
      primary_outcome = row["Other Primary Outcomes"]
      patient_id = PatientIdentifier.find_by_identifier(identifier).patient_id rescue nil
      next if patient_id.blank? || start_date.blank?
      
      day = start_date.split("-")[0]
      month = Date::ABBR_MONTHNAMES.index(start_date.split("-")[1])
      year = start_date.split("-")[2]
      date = Utils.format_date("#{month}/#{day}/#{year}")
      initiation_date = "#{date} 00:00:00"
    begin
      outcome_date = row['Outcome Date']
      month = Date::ABBR_MONTHNAMES.index(outcome_date.split("-")[1])
      year = outcome_date.split("-")[2]
      outcome_date = Utils.format_date("#{month}/#{day}/#{year}")
      outcome_date = "#{outcome_date} 00:00:00"
    rescue
      outcome_date = Date.today
    end

    begin

      patient_program = PatientProgram.create(:patient_id => patient_id,
                                              :program_id => @@program.id, :date_enrolled => initiation_date)
      next if patient_program.blank?
      last_state = PatientState.create(:patient_program_id => patient_program.id, :state => 1, :start_date => initiation_date)

      puts "Update outcome to Pre ART: #{patient_id}  #{initiation_date}"

      arv_dispensed, arv_start_date = Utils.has_arv_dispensed(patient_id)

      if arv_dispensed == true

        last_state.update_attributes(:end_date => initiation_date)
        puts "Update outcome to On ART: #{patient_id}  #{initiation_date}"
        last_state = PatientState.create(:patient_program_id => patient_program.id, :state => 7, :start_date => initiation_date)

      end

      unless patient_died.blank?

        last_state.update_attributes(:end_date => outcome_date)
        last_state = PatientState.create(:patient_program_id => patient_program.id, :state => 3,
                                         :start_date => outcome_date, :end_date => outcome_date)

        puts "Update outcome to dead: #{patient_id}  #{outcome_date}"

      end

      if primary_outcome == "TO"

        last_state.update_attributes(:end_date => outcome_date)
        last_state = PatientState.create(:patient_program_id => patient_program.id, :state => 2,
                                         :start_date => outcome_date, :end_date => outcome_date)
        puts "Update outcome to Transfered Out: #{patient_id}  #{outcome_date}"
      end

      if primary_outcome == "Stop"

        last_state.update_attributes(:end_date => outcome_date)
        last_state = PatientState.create(:patient_program_id => patient_program.id, :state => 6,
                                         :start_date => outcome_date, :end_date => outcome_date)
        puts "Update outcome to Stop ARV: #{patient_id}  #{outcome_date}"

      end

    rescue
      # log errors
    end


  end

end

start