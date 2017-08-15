require 'yaml'

 YAML.load_file('/var/www/national_art/script/FUCHIA/data.yml')
#puts config['last_update'] #in my file this is set to "some data"
#config['last_update'] = "other data"
#data = {"name" => "Xavier","location" => "Unknown","parent" => "process orignator"}
data = Hash.new { |hash, key| hash[key] =  }
data["firstkey"]["secondkey"]["thirdkey"] ={}
File.open('/var/www/national_art/script/FUCHIA/data.yml','w') do |h|
   #h.write "{" + data + "}".to_yaml
   YAML.dump(data,h)
end
