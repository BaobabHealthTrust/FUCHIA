User.current = User.first

@@arv_concept_ids = MedicationService.arv_drugs.map(&:concept_id)
@@regimen_category = ConceptName.find_by_name('Regimen Category').concept
@@dispensing_encounter = EncounterType.find_by_name('DISPENSING')
def start


  data = Observation.find(:all, :joins =>"INNER JOIN drug_order o ON o.order_id = obs.order_id
    INNER JOIN drug ON drug.drug_id = o.drug_inventory_id", 
    :conditions =>["drug.concept_id IN(?)", @@arv_concept_ids],:group => "obs.person_id",
    :select => "person_id, obs_datetime, drug_inventory_id, obs.order_id")


  (data || []).each do |d|
    begin
      person_id = d['person_id'].to_i
      order_id = d['order_id'].to_i
      obs_datetime = d['obs_datetime'].to_time
    rescue
      next
    end

    dispensed_arvs = get_dispensed_arvs(person_id, obs_datetime)
    unless dispensed_arvs.blank?
      arv_regimen = MedicationService.regimen_interpreter(dispensed_arvs)
      unless arv_regimen.match(/unknown/i)
        set_regimen(person_id, obs_datetime, arv_regimen)
      end
    else
      #puts "::::::::::::: #{dispensed_arvs}"
    end
  end

end


def set_regimen(person_id, obs_datetime, arv_regimen)
  encounter = Encounter.find(:first, :conditions =>["patient_id = ? 
    AND encounter_type = ? AND encounter_datetime BETWEEN ? AND ?", person_id,
    @@dispensing_encounter.id, obs_datetime.strftime('%Y-%m-%d 00:00:00'),
    obs_datetime.strftime('%Y-%m-%d 23:59:59')])

  return if encounter.blank?
  Observation.create(:concept_id => @@regimen_category.id, :person_id => person_id,
    :value_text => arv_regimen, :encounter_id => encounter.id, :obs_datetime => encounter.encounter_datetime)
  puts "Set: #{arv_regimen} for patient_id: #{person_id}"
end

def get_dispensed_arvs(patient_id, obs_datetime)
  start_date = obs_datetime.strftime('%Y-%m-%d 00:00:00')
  end_date = obs_datetime.strftime('%Y-%m-%d 23:59:59')

  order_ids = Order.find(:all, :conditions => ["patient_id = ? AND start_date BETWEEN ? AND ?",
    patient_id, start_date, end_date]).map(&:order_id) rescue [0]

  return Drug.find(:all, :joins =>"INNER JOIN drug_order o ON o.drug_inventory_id = drug.drug_id", 
    :conditions =>["concept_id IN(?) AND o.order_id IN(?)", 
    @@arv_concept_ids, order_ids],:group => "o.drug_inventory_id").map(&:drug_id)
end

start 
