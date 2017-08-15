require 'fastercsv'
class Utilities

  set_up = File.read('config/setup_params.json')
  set_up_data = JSON.parse(set_up)
  site_name = set_up_data['site_name'].gsub(/\s+/, " ").split(" ")[0].downcase
  Parent_path = set_up_data['source_path'] #/home/pachawo/Documents/msf/msf_data/namitambo
  Destination_path = "#{File.expand_path('~')}/msf_#{site_name}/" #'/home/pachawo/Documents/msf/msf_data/namitambo/'

  $patient_drug = {}
  $references = {}
  $drug_follow_up = {}
  $dead_patients = {}
  $transfered_patients = {}
  @@drug_mapped = {}
  $fuchia_ids = []
  

  def get_fuchia_ids
    FasterCSV.foreach("#{Parent_path}fuchia_ids.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|
        $fuchia_ids << row['FUCHIA ID']
       # puts "#{$fuchia_ids} >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    end 

     return $fuchia_ids  
  end

  def get_dead_patients

    FasterCSV.foreach("#{Parent_path}TbPatient.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      deceased_date = row[21]

      deceased_id = row[0]

      if !deceased_date.blank?

        deceased_date = format_date(deceased_date)

        $dead_patients[deceased_id]= deceased_date

      end


    end

    return $dead_patients

  end

  def get_transfered_out_patients

    FasterCSV.foreach("#{Parent_path}TbPatient.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      transfered_out_date = row[23]

      patient_id = row[0]

      if !transfered_out_date.blank?

        transfered_out_date = format_date(transfered_out_date)

        $transfered_patients[patient_id] = transfered_out_date

      end

    end

    return $transfered_patients

  end

  def drug_mapping

    set_references

    drug_map = Utilities.new.drug_mapped

    FasterCSV.foreach("#{Parent_path}TbFollowUpDrug.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      follow_up_ref = row[3].to_i

      visit_date = format_date(row[1]).to_date rescue nil

      prescription = row[5].to_i

      next if visit_date.blank?

      if $drug_follow_up[follow_up_ref].blank?

        $drug_follow_up[follow_up_ref] = []

      end

      $drug_follow_up[follow_up_ref] << [drug_map[$references[row[4].to_i]],prescription]
      $drug_follow_up[follow_up_ref] = $drug_follow_up[follow_up_ref].uniq

      puts "Mapping medication: #{drug_map[$references[row[4].to_i]]} ...."

    end

    return $drug_follow_up

  end

  def drug_on_initial_visit

    set_references

    drug_map = Utilities.new.drug_mapped

    FasterCSV.foreach("#{Parent_path}TbPatientDrug.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      patient_id = row['FdxReferencePatient'].to_i

      if $patient_drug[patient_id].blank?

        $patient_drug[patient_id] = []

      end

      $patient_drug[patient_id] << drug_map[$references[row['FdxReferenceDrug'].to_i]]
      $patient_drug[patient_id] = $patient_drug[patient_id].uniq

    end

    return $patient_drug

  end

  def get_drug_status(prescription)

    if prescription.to_i < 4

      return 0

    elsif prescription.to_i >= 4

      return 1

    end

  end

  def set_references

    FasterCSV.foreach("#{Parent_path}TbReference.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      $references[row[0].to_i] = row[6]
      # puts ":: #{row[6]}"

    end

    return $references

  end

  def get_patient_who_stage(who, age)

    if who != 0

      if age <= 15

        who_category = "peds"

      else

        who_category = "adult"

      end

      case who_category

        when "peds"

          who_stage = get_who_stage(who)

          who_stage = who_stage.to_s + who_category.to_s

        when "adult"

          who_stage = get_who_stage(who)

          who_stage = who_stage.to_s + who_category.to_s

      end

    end

  end

  def get_who_stage(who)

    unless who == 0

      if who == 1

        who_stage = "WHO stage I "

      elsif who == 2

        who_stage = "WHO stage II "

      elsif who == 3

        who_stage = "WHO stage III "

      elsif who == 4

        who_stage = "WHO stage IV "

      end

      return who_stage

    end

  end

  def generate_date_of_birth(age, date_recorded)

    age = age.to_i
    date_of_birth = date_recorded.to_date - age.year

  end

  def format_date(unformatted_date)

    if !unformatted_date.blank?

      unformatted_date = unformatted_date.split("/")
      year_of_birth = unformatted_date[2].split(" ")
      year_of_birth = year_of_birth[0]
      current_year = Date.today.year.to_s

      if year_of_birth.to_i > current_year[-2..-1].to_i

        year = "19#{year_of_birth}"

      else

        year = "20#{year_of_birth}"

      end
      month = unformatted_date[0]
      day = unformatted_date[1]
	
      if (unformatted_date[0].length == 1)
	month = "0#{unformatted_date[0]}"
      end
      if (unformatted_date[1].length == 1)
	day = "0#{unformatted_date[1]}"
      end

      fomatted_date = "#{year}-#{month}-#{day}"
    else

      return nil

    end

  end

  def close_sql_with_semi_colon(file_path)

    raw_sql = File.read("#{file_path}")[0...-1]

    File.open("#{file_path}", "w") {|sql| sql.puts raw_sql << ";"}

  end


  def create_observation_value_coded(encounter, concept_name, value_coded_concept_name,destination_path)

    concept_id = ConceptName.find_by_name(concept_name).concept_id

    value = ConceptName.find_by_name(value_coded_concept_name)

    value_coded = value.concept_id

    value_coded_name_id = value.concept_name_id

    uuid =ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF

    insert_observation_value_coded = "(#{encounter.patient_id},#{encounter.id},#{concept_id},NULL,"

    insert_observation_value_coded += "\"#{value_coded}\",NULL,\"#{value_coded_name_id}\",NULL,NULL,NULL,"

    insert_observation_value_coded += "\"#{encounter.encounter_datetime.strftime("%Y-%m-%d 00:00:00")}\","

    insert_observation_value_coded += "\"#{User.current.id}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_observation_value_coded}' >> #{destination_path}`

  end

  def create_observation_value_text(encounter, concept_name, value_text,destination_path)

    concept_id = ConceptName.find_by_name(concept_name).concept_id

    uuid =ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF
    insert_observation_value_text = "(#{encounter.patient_id},#{encounter.encounter_id},#{concept_id},NULL,"

    insert_observation_value_text += "NULL,\"#{value_text}\",NULL,NULL,\"#{encounter.encounter_datetime}\","

    insert_observation_value_text += "\"#{User.current.id}\",\"#{encounter.date_created}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_observation_value_text}' >> #{destination_path}`
  end


  def create_observation_value_datetime(encounter, concept_name, date,destination_path)

    concept_id = ConceptName.find_by_name(concept_name).concept_id

    uuid =ActiveRecord::Base.connection.select_one <<EOF
     select uuid();
EOF
    insert_observation_value_datetime = "(#{encounter.patient_id},#{encounter.id},#{concept_id},NULL,NULL,NULL,NULL"

    insert_observation_value_datetime += "\"#{date}\",NULL,NULL,\"#{encounter.encounter_datetime.strftime("%Y-%m-%d 00:00:00")}\","

    insert_observation_value_datetime += "\"#{User.current.id}\",\"#{uuid.values.first}\"),"

    `echo -n '#{insert_observation_value_datetime}' >> #{destination_path}`
  end

  def has_arv_dispensed(patient_id)

    orders = Order.find(:all, :conditions => ["patient_id = ?", patient_id])

    (orders || []).each do |order|
      concept_id = order['concept_id']
      concept_set = ConceptSet.find_by_concept_id(concept_id).concept_set rescue nil
      if concept_set.to_i == 1085
        return true, order['start_date']
      end
    end

    return false, nil

  end


  def drug_mapped

    @@drug_mapped = {
        "Cotrimoxazole prophylaxis" => ['Cotrimoxazole (960mg)'],
        "FDC3 (AZT-3TC-NVP)" => ['AZT/3TC/NVP (300/150/200mg tablet)'],
        "Efavirenz 600" => ['EFV (Efavirenz 600mg tablet)'],
        "Isoniazide prophylaxis" => ['INH or H (Isoniazid 100mg tablet)'],
        "FDC11 (TDF-3TC-EFV)" => ['TDF/3TC/EFV (300/300/600mg tablet)'],
        "FDC1 (D4T30-3TC-NVP)" => ['d4T/3TC (Stavudine Lamivudine 30/150 tablet)','NVP (Nevirapine 200 mg tablet)'],
        "Lamivudine" => ['3TC (Lamivudine 150mg tablet)'],
        "Stavudine (dosage unspecified)" => ['d4T (Stavudine 30mg tablet)'],
        "Nevirapine" => ['NVP (Nevirapine 200 mg tablet)'],
        "FDC2 pediatric (AZT-3TC-NVPp)" => ['AZT/3TC/NVP (60/30/50mg tablet)'],
        "FDC10 (TDF-3TC)" => ['TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet'],
        "Atazanavir/Ritonavir" => ['ATV/r (Atazanavir 300mg/Ritonavir 100mg)'],
        "FDC2 (D4T40-3TC-NVP)" => ['Triomune-40'],
        "FDC5 (D4T30-3TC)" => ['Triomune-30'],
        "Dapsone prophylaxis" => ['Dapsone (100mg tablet)'],
        "Kaletra (Lopinavir/Ritonavir) pediatric" => ['LPV/r (Lopinavir and Ritonavir 100/25mg tablet)'],
        "FDC5 pediatric (ABC-3TCp)" => ['ABC/3TC (Abacavir and Lamivudine 60/30mg tablet)'],
        "FDC7 (AZT-3TC)" => ['AZT/3TC (Zidovudine and Lamivudine 300/150mg)'],
        "Fluconazole secondary prophylaxis" => ['Fluconazole (200mg tablet)'],
        "FDC4 pediatric (AZT-3TCp)" => ['AZT/3TC (Zidovudine and Lamivudine 60/30 tablet)'],
        "Stavudine 30" => ['d4T (Stavudine 30mg tablet)'],
        "FDC1 pediatric (D4T30-3TC-NVPp)" => ['Triomune baby (d4T/3TC/NVP 6/30/50mg tablet)'],
        "Kaletra (Lopinavir/Ritonavir)" => ['LPV/r (Lopinavir and Ritonavir 200/50mg tablet)'],
        "Efavirenz pediatric" =>['EFV (Efavirenz 50mg tablet)'],
        "Nevirapine pediatric" => ['NVP (Nevirapine 50 mg tablet)'],
        "Lamivudine pediatric" => ['3TC (Lamivudine syrup 10mg/mL from 100mL bottle)'],
        "Abacavir pediatric" => ['Unknown'],
        "Ritonavir" => ['Ritonavir 100mg'],
        "Darunavir" => ['Darunavir 600mg'],
        "Raltegravir" => ['RAL (Raltegravir 400mg)'],
        "Abacavir" => ['ABC (Abacavir 300mg tablet)'],
        "Fluconazole primary prophylaxis" => ['FCZ (Fluconazole 150mg tablet)'],
        "Tenofovir" => ['TDF (Tenofavir 300 mg tablet)'],
        "FDC3 pediatric (D4T30-3TCp)" =>  ['d4T/3TC (Stavudine Lamivudine 30/150 tablet)'],
        "Zidovudine" => ['AZT (Zidovudine 300mg tablet)'],
        "FDC12 (TDF-3TC-NVP)" => ['TDF/3TC (Tenofavir and Lamivudine 300/300mg tablet'],
        "Nelfinavir" => ['NFV(Nelfinavir)'],
        "Didanosine 250" => ['DDI (Didanosine 125mg tablet)'],
        "Zidovudine (Mother to child)" => ['AZT (Zidovudine 300mg tablet)'],
        "Nevirapine (Mother to child)" => ['NVP (Nevirapine 200 mg tablet)'],
        "Didanosine 400" => ['DDI (Didanosine 200mg tablet)'],
        "Other ARV 2" => ['Unknown'],
        "Zidovudine pediatric" => ['AZT (Zidovudine 100mg tablet)'],
        "FDC6 (D4T40-3TC)" => ['d4T/3TC (Stavudine Lamivudine 30/150 tablet)'],
        "Other ARV 1" => ['Unknown'],
        "Stavudine pediatric" => ['d4T (Stavudine 30mg tablet)'],
        "Stavudine 40" => ['d4T (Stavudine 40mg tablet)'],
        "Nelfinavir pediatric" => ['NFV(Nelfinavir)'],
        "Efavirenz 800" => ['EFV (Efavirenz 600mg tablet)'],
        "Atazanavir" => ['ATV/(Atazanavir)'],
        "NVP Single Dose + (AZT-3TC) regimen (Mother to child)" => ['AZT/3TC (Zidovudine and Lamivudine 300/150mg)','NVP (Nevirapine 200 mg tablet)']
    }

  end

  def visit_drug
    @regimen_map = {
        '3TC+ABC+NVP' => '0A',
        'FDC5p (ABC-3TCp)+NVPp' => '0P',
        'NVPp+FDC5p (ABC-3TCp)' => '0P',
        'FDC10 (TDF-3TC)+LPV/r' => '10A',
        'LPV/r+FDC10 (TDF-3TC)' => '10A',
        'FDC7 (AZT-3TC)+LPV/r' => '11A',
        'LPV/r+FDC7 (AZT-3TC)' => '11A',
        '3TC+DRV+RAL+RTV+TDF' => '12A',
        'FDC3 (AZT-3TC-NVP)' => '2A',
        'FDC2p (AZT-3TC-NVPp)' => '2P',
        'EFV600+FDC7 (AZT-3TC)' => '4A',
        'FDC7 (AZT-3TC)+EFV600' => '4A',
        'EFVp+FDC4p (AZT-3TCp)' => '4P',
        'FDC4p (AZT-3TCp)+EFVp' => '4P',
        '3TCp+AZTp+EFVp' => '4P',
        'FDC11 (TDF-3TC-EFV)' => '5A',
        'EFV600+FDC10 (TDF-3TC)' => '5A',
        'FDC10 (TDF-3TC)+NVP' => '6A',
        'NVP+FDC10 (TDF-3TC)' => '6A',
        'ATZ/r+FDC10 (TDF-3TC)' => '7A',
        'FDC10 (TDF-3TC)+ATZ/r' => '7A',
        'FDC7 (AZT-3TC)+ATZ/r' => '8A',
        'ATZ/r+FDC7 (AZT-3TC)' => '8A',
        'ATZ+FDC10 (TDF-3TC)' => '8A',
        'FDC10 (TDF-3TC)+ATZ' => '8A',
        '3TC+ABC+LPV/r' => '9A',
        'FDC5p (ABC-3TCp)+LPV/rp' => '9P',
        'LPV/rp+FDC5p (ABC-3TCp)' => '9P',
        '3TCp+ABCp+LPV/rp' => '9P'
    }
    codes = Utilities.new.get_drug_code

    @follow_up_drug = {}

    FasterCSV.foreach("#{Parent_path}TbFollowUpDrug.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      follow_up_ref = row['FdxReferenceFollowUp'].to_i

      drug_id = row['FdxReferenceDrug'].to_i

      presc = row['FdnPrescription'].to_i

      if @follow_up_drug[follow_up_ref].blank?

        @follow_up_drug[follow_up_ref] = []

      end

      @follow_up_drug[follow_up_ref] << codes[drug_id] rescue nil #if Utilities.new.get_drug_status(presc) == 2

      #@follow_up_drug[follow_up_ref] = @follow_up_drug[follow_up_ref].uniq

    end

    return @follow_up_drug
  end

  def follow_up_patient

    @patient_follow_up_visits = {}

    FasterCSV.foreach("#{Parent_path}tb_follow_up.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      patient_id = row['FdxReferencePatient'].to_i

      if @patient_follow_up_visits[patient_id].blank?

        @patient_follow_up_visits[patient_id] = []

      end

      @patient_follow_up_visits[patient_id] << row['FdxReference'].to_i

      @patient_follow_up_visits[patient_id] = @patient_follow_up_visits[patient_id].uniq

    end

    return @patient_follow_up_visits

  end

  def get_drug_code

    @short_codes = {}

    FasterCSV.foreach("#{Parent_path}TbReference.csv", :headers => true, :quote_char => '"', :col_sep => ',', :row_sep => :auto) do |row|

      ref_id = row['FdxReference'].to_i

      if @short_codes[ref_id].blank?

        @short_codes[ref_id] = "#{row['FdsLookupShort']}"

      end

    end

    return @short_codes

  end

  def get_regimen(drug)
    non_arv_drugs = ["COTRI","INH","FLUCO1","FLUCO2","ITR","DAP"]
    begin

      case drug.length

        when 1
          drug_one =  get_fdc_drug(drug[0]) unless non_arv_drugs.include?drug[0]
          fddvisitarvlast = "#{drug_one}"

        when 2
          drug_one = "#{get_fdc_drug(drug[0])}+" unless non_arv_drugs.include?drug[0]
          drug_two = "#{get_fdc_drug(drug[1])}" unless non_arv_drugs.include?drug[1]
          fddvisitarvlast = "#{drug_one}#{drug_two}"

        when 3
          drug_one = "#{get_fdc_drug(drug[0])}+" unless non_arv_drugs.include?drug[0]
          drug_two = "#{get_fdc_drug(drug[1])}+" unless non_arv_drugs.include?drug[1]
          drug_three = "#{get_fdc_drug(drug[2])}" unless non_arv_drugs.include?drug[2]
          fddvisitarvlast = "#{drug_one}#{drug_two}#{drug_three}"

      end

      if fddvisitarvlast[-1,1].to_s == "+"
        fddvisitarvlast = fddvisitarvlast.chomp('+')
      end

      return @regimen_map[fddvisitarvlast]

    rescue

    end

  end

  def get_fdc_drug(drug)

    @fdc_lookup = {
        'FDC1' =>	'FDC1 (D4T30-3TC-NVP)',
        'FDC10' => 'FDC10 (TDF-3TC)',
        'FDC11' => 'FDC11 (TDF-3TC-EFV)',
        'FDC12' => 'FDC12 (TDF-3TC-NVP)',
        'FDC1p' => 'FDC1p (D4T30-3TC-NVPp)',
        'FDC2' => 'FDC2 (D4T40-3TC-NVP)',
        'FDC2p' => 'FDC2p (AZT-3TC-NVPp)',
        'FDC3' => 'FDC3 (AZT-3TC-NVP)',
        'FDC3p' => 'FDC3p (D4T30-3TCp)',
        'FDC4' => 'FDC4 (AZT-3TC-ABC)',
        'FDC4p' => 'FDC4p (AZT-3TCp)',
        'FDC5' => 'FDC5 (D4T30-3TC)',
        'FDC5p' => 'FDC5p (ABC-3TCp)',
        'FDC6' => 'FDC6 (D4T40-3TC)',
        'FDC6p' => 'FDC6p (D4T-3TCp)',
        'FDC7' => 'FDC7 (AZT-3TC)',
        'FDC8' => 'FDC8 (Tenofovir-FTC)',
        'FDC9' => 'FDC9 (EFV-TDF-FTC)'
    }

    if drug.include?"FDC"
      name = @fdc_lookup[drug]
    else
      name = drug
    end

    return name
  end

  def getLastAppointmentDate(id)


    encounter_type_id = EncounterType.find_by_name("Appointment").id

    concept_id = Encounter.find(:last, :conditions =>["encounter_type =? and patient_id =?",encounter_type_id,id]).encounter_id rescue nil

    appointmentdate  = Observation.find(:last, :conditions =>["encounter_id = ? and person_id =?",concept_id, id]) rescue nil


    return appointmentdate.value_datetime unless appointmentdate.nil?

  end

  def checkIfPatientIsDefaulter(patient_id)

    currentdate = "31-March-2017".to_date
    appointmentdate = Utilities.new.getLastAppointmentDate(patient_id)

    if !appointmentdate.blank?

      if((currentdate - appointmentdate.to_date).to_i >= 60)
        defaulter = true
      else
        defaulter = false
      end
    else
      defaulter = false
    end

    return defaulter

  end

end


