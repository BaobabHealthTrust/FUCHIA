User.current = User.first
TBStatusConcept = ConceptName.find_by_name('TB Status').concept
Clinical_visit = EncounterType.find_by_name('HIV CLINIC CONSULTATION')
HIV_STAGING = EncounterType.find_by_name('HIV STAGING')

def start
  encounters = Encounter.find(:all, :conditions =>["encounter_type = ? OR encounter_type = ?", Clinical_visit.id, HIV_STAGING.id])
  #visits = Observation.find(:all, :conditions => ["encounter_id IN(?)", encounter_ids])

  (encounters || []).each do |e|
    tb_status_done = false
    (e.observations || []).each do |obs|
      tb_status_done = true if obs.to_s.match(/TB status/i)
      puts "-------------- #{obs.to_s}"
      break if tb_status_done
    end

    puts "........ #{e.patient_id}::::#{tb_status_done}" if tb_status_done
  end

end

def fix
  visits = Observation.find(:all, :conditions => ["concept_id = ?", TBStatusConcept.id])

  (visits || []).each do |v|
    e = Encounter.find(:first, :conditions =>["patient_id = ? AND encounter_datetime BETWEEN (? AND ?)
      AND encounter_type = ?", v.person_id, v.obs_datetime.to_date.strftime('%Y-%m-%d 00:00:00'),
      v.obs_datetime.to_date.strftime('%Y-%m-%d 23:59:59'), Clinical_visit.id])

    begin
      e = Encounter.create(:patient_id => v.person_id, 
        :encounter_datetime => v.obs_datetime.to_date.strftime('%Y-%m-%d 00:00:00'),
        :encounter_type => Clinical_visit.id)

      v.update_attributes(:encounter_id => e.id)
    rescue
      v.update_attributes(:encounter_id => e.id)
    end

    puts "............. update: #{v.id}"
  end

end

fix
#start
