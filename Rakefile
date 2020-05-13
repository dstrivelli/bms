# frozen_string_literal: true

require 'English'
require 'fileutils'
require 'rake'
require 'pry'

require_relative 'version'

LOCAL_YAML    = 'config/environments/production.yml'
HELM_YAML     = 'charts/bms/config/production.yml'
HELM          = 'helm3'
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

desc 'Load authentication tokens for testing'
task :setup, [:username, :password] do |_, args|
  require 'faraday'
  require 'yaml'
  config = YAML.safe_load(File.read(File.expand_path('~/.kube/config')))
  token = config['users'].first['user']['auth-provider']['config']['id-token']
  File.open('local/k8_token', 'w') { |file| file.puts token }

  oauth_url = URI('https://oauth.prod8.bip.va.gov/')
  response = Faraday.get oauth_url.merge('/oauth2/start?rd=https://kibana.prod8.bip.va.gov/')
  csrf_cookie = response.headers['set-cookie'].split(';', 2).first + ';'
  dex_url = URI(response.headers['location'])
  response = Faraday.get(dex_url)
  auth = { 'login' => args.username, 'password' => args.password }
  response = Faraday.post(dex_url.merge(response.headers['location']), auth)
  raise 'Oauth2 Login Failed.' unless response.status == 303

  response = Faraday.get(dex_url.merge(response.headers['location']))
  response = Faraday.get(response.headers['location']) do |req|
    req.headers['cookie'] = csrf_cookie
  end
  oauth_cookie = /(_oauth2_proxy=[^;]*;)/.match(response.headers['set-cookie'])[1]
  File.open('local/_oauth2_proxy', 'w') { |f| f.puts oauth_cookie }
end

desc 'Build docker image'
task :build do
  # Validate rubocop is clean
  Rake::Task[:rubocop].invoke
  # Run RSpec test
  Rake::Task[:spec].invoke

  puts 'Building ctags...'
  `ctags -R`

  puts 'Copying production.yml to helm chart.'
  FileUtils.copy_file(LOCAL_YAML, HELM_YAML, preserve: true)

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

desc 'Deploy latest version via Helm'
task :deploy do
  require 'digest'
  # Verify the production.yml is correct.
  local_yml = Digest::MD5.hexdigest File.read(LOCAL_YAML)
  helm_yml = Digest::MD5.hexdigest File.read(HELM_YAML)
  local_yml == helm_yml || FileUtils.copy_file(LOCAL_YAML, HELM_YAML, preserve: true)
  `#{HELM} upgrade bms charts/bms --namespace=bms`
end

desc 'Flush Redis database'
task :flush do
  require 'ohm'
  require 'config'
  redis_host = Settings&.redis || 'redis://127.0.0.1:6379'
  Ohm.redis = Relic.new(redis_host)
  puts Ohm.flush
end
