# frozen_string_literal: true

$LOAD_PATH << File.join(__dir__, 'lib')

require 'English'
require 'fileutils'
require 'rake'
require 'bms/version'

REMOTE_DOCKER = 'container-registry.prod8.bip.va.gov'

# Setup some embedded tasks
begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new(:rubocop) do |t|
    t.options = ['--display-cop-names']
  end
rescue LoadError
end

desc 'Build docker image'
task :build do
  # Validate rubocop is clean
  Rake::Task[:rubocop].invoke
  # Validate no bindings left in source
  results = `find #{__dir__} -type f -exec egrep -Hn '^[^#]*binding\.(irb|pry|pry_remote)' {} \\;`
  raise 'Failed to validate no bindings present.' unless $CHILD_STATUS == 0

  unless results.empty?
    puts 'Validation failed. Ruby bindings found in the following instances:'
    puts results
    exit 1
  end

  puts 'Building ctags...'
  `ctags -R`

  puts 'Copying production.yml to helm chart.'
  FileUtils.copy_file(
    'config/environments/production.yml',
    'charts/bms/config/production.yml',
    preserve: true
  )

  puts 'Building local docker image...'
  status = system("docker image build -t bms:#{BMS::VERSION} .")
  if status
    puts 'Success!'
  else
    puts 'Error!'
  end
end

desc "Push docker image to #{REMOTE_DOCKER}"
task :push do
  puts "Tagging bms:#{BMS::VERSION} -> #{REMOTE_DOCKER}:#{BMS::VERSION}"
  status = system("docker tag bms:#{BMS::VERSION} #{REMOTE_DOCKER}/bms:#{BMS::VERSION}")
  raise unless status

  puts "Pushing bms:#{BMS::VERSION} -> #{REMOTE_DOCKER}:#{BMS::VERSION}"
  status = system("docker push #{REMOTE_DOCKER}/bms:#{BMS::VERSION}")
  if status
    puts 'Image successfully push!'
  else
    puts 'Image failed to push due to fatal error!'
  end

  puts 'Cleaning up tag'
  system("docker rmi #{REMOTE_DOCKER}/bms:#{BMS::VERSION}")
end

desc 'Run docker bms for testing'
task :run do
  secrets_dir = '/var/run/secrets/kubernetes.io/serviceaccount'
  mount_path = File.join(ENV.fetch('TELEPRESENCE_ROOT', ''), secrets_dir)
  # Start the container doing nothing
  system("docker run --detach --net=host --dns 127.0.0.53 --name=bms bms:#{BMS::VERSION} ruby -e 'sleep'")
  # Make the directory needed for kubectl creds
  system("docker exec bms mkdir -p #{secrets_dir}")
  # Copy the kubectl creds into container
  system("docker cp #{mount_path} bms:#{secrets_dir}/..")
  # Start a shell
  system('docker exec -it bms /bin/sh')
  # Stop and delete the container
  system('docker stop bms')
  system('docker rm bms')
end
