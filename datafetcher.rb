User.current = User.find_by_username('admin')
Parent_path = '/home/comish/Desktop/msf/'
require 'fastercsv'
require 'date'

def start
   location_ref = locationReference

   FasterCSV.foreach("#{Parent_path}/TbPatient.csv", :quote_char => '"', :col_sep =>',', :row_sep =>:auto, :headers => :true) do |row|
    names = row[9].split(' ')
    given_name = names[0].titleize.squish rescue nil
    family_name = names.last.titleize.squish rescue nil
    given_name = given_name.gsub('*','') unless given_name.blank?
    family_name = family_name.gsub('*','') unless family_name.blank?

    gender = row[10].squish.to_i rescue 'Unknown'
    unless gender == 'Unknown'
      gender = gender == 0 ? 'M' : 'F'
    end

    location_reference_id = row[3]
    address = location_ref[location_reference_id]

    age = row[12].to_i rescue nil
    #raise age.inspect
    #raise address.inspect
    #location_ref.each do |k, v|
       #puts ">>>: #{k} : #{v}"
    #end



    date_recorded = row[14].to_datetime rescue nil
    #puts "date recorded #{date_recorded.inspect}"

    date_of_birth = row[11].split(' ').to_date rescue nil
    #dob = row[11].split(' ').first rescue nil
    if  date_of_birth.blank? and age.present?
        date_of_birth = (date_recorded - age.year)
    end

    puts "date of birth #{date_of_birth.inspect}"

    year_of_birth = date_of_birth.split('/').last.to_i

    #puts "YEAR OF BIRTH #{year_of_birth.inspect}"

    if year_of_birth > 16 then
      year_of_birth = year_of_birth + 1900
    else
     year_of_birth = year_of_birth + 2000
    end

    #date_of_birth[2] = year_of_birth
    sanitised_date = date_of_birth.split('/')
    sanitised_date[2] = year_of_birth.to_s

    sanitised_date = Time.parse(sanitised_date)
    #raise sanitised_date.inspect








    #puts ">>> #{given_name} #{family_name} (#{gender})"

    puts ">>> #{given_name} #{family_name} (#{gender}) #{date_created.strftime("%d/%b/%Y")} #{date_of_birth.strftime("%d/%b/%")} #{address}"


   end
end

def generate_date_of_birth(age, date_recorded)
  age = age.to_i
  date_of_birth = date_recorded.to_date - age.year
end

def locationReference

    addressesData = {}
    FasterCSV.foreach("#{Parent_path}/TbReference.csv", :quote_char => '"', :col_sep =>',', :row_sep =>:auto, :headers => :true) do |row|
       addressesData[row[0]] = row[6]
    end

   #addressesData.each do |k, v|
      #puts "key : #{k} value : #{v}"
   #end
   return addressesData
end

#locationReference
#referenceTbl
#values = referenceTbl
#puts values[0].inspect
start
