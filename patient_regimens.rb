require "script/FUCHIA/utilities.rb"

User.current = User.first

Utils = Utilities.new
@visits = Utils.follow_up_patient
@drugs = Utils.visit_drug

@@regimen_category = ConceptName.find_by_name('Regimen Category').concept
@@dispensing_encounter = EncounterType.find_by_name('DISPENSING')

#raise @drugs.inspect
#raise Utils.get_regimen(["EFVp","FDC10"]).inspect

def start

  p_ids = Patient.all

  p_ids.each do |p_id|
    patient_id = p_id.patient_id.to_i
    patient_visits = @visits[patient_id]
    visit = []

    next if Utils.checkIfPatientIsDefaulter(patient_id) == true

    begin

      encounter = Encounter.find(:last, :conditions =>["patient_id = ? AND encounter_type = ?",
                                                       patient_id,@@dispensing_encounter.id])

      if patient_visits.length > 1

        first_visit = Utils.get_regimen(@drugs[patient_visits.min])
        last_visit = Utils.get_regimen(@drugs[patient_visits.max])

        visit << "#{first_visit}"
        visit << "#{last_visit}"

      else

        visit << "#{Utils.get_regimen(@drugs[patient_visits])}"

      end

      visit = visit.last #  > 1 ? visit[1] : visit[0]

      Observation.create(:concept_id => @@regimen_category.id, :person_id => patient_id,
                         :value_text => visit, :encounter_id => encounter.id, :obs_datetime => encounter.encounter_datetime)

      puts "Regimen #{visit} for #{patient_id} on #{encounter.encounter_datetime.strftime('%Y-%m-%d 00:00:00')}" unless visit == ""

    rescue

    end
  end
end
start
