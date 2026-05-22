# frozen_string_literal: true

require 'rake/testtask'
require './require_app'

task default: :spec

desc 'Prints the current environment'
task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run rubocop to check style'
task :style do
  sh 'rubocop .'
end

desc 'Test all the specs'
Rake::TestTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.warning = false
end

desc 'Run application console (pry)'
task console: [:print_env] do
  sh 'pry -r ./spec/test_load_all'
end

namespace :run do
  desc 'Run Web App in development mode'
  task dev: [:print_env] do
    sh 'puma -p 9292'
  end
end

namespace :generate do
  desc 'Create cookie session secret'
  task :session_secret do
    require_app('lib', config: false)

    puts "New SESSION_SECRET (base64): #{LockedCV::SecureSession.generate_secret}"
  end
end

namespace :session do
  desc 'Wipe all sessions stored in Redis'
  task :wipe_redis_sessions do
    require_app('lib')

    puts 'Deleting all sessions from Redis session store'
    wiped = LockedCV::SecureSession.wipe_redis_sessions
    puts "#{wiped.count} sessions deleted"
  end
end

namespace :newkey do
  desc 'Create rbnacl SecretBox key for SecureMessage'
  task :msg do
    require_app('lib', config: false)

    puts "New MSG_KEY (base64): #{LockedCV::SecureMessage.generate_key}"
  end
end
