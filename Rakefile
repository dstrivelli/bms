$: << File.join(__dir__, 'lib')

require 'rake'

require 'bms/version'

desc 'Build docker image'
task :build do
  puts 'Building local docker image...'
  status = system("docker image build -t bms:#{BMS::VERSION} .")
  if status
    puts 'Success!'
  else
    puts 'Error!'
  end
end

desc 'Push docker image to container-registry.prod8.bip.va.gov'
task :push do
  status = system("docker tag bms:#{BMS::VERSION} container-registry.prod8.bip.va.gov/bms:#{BMS::VERSION}")
  raise unless status
  status = system("docker push container-registry.prod8.bip.va.gov/bms:#{BMS::VERSION}")
  if status
    puts 'Success!'
  else
    puts 'Error!'
  end
end
