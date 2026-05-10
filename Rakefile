# frozen_string_literal: true

require './require_app'

task default: :style

desc 'Prints the current environment'
task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run rubocop to check style'
task :style do
  sh 'rubocop .'
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

namespace :newkey do
  desc 'Create rbnacl SecretBox key for SecureMessage'
  task :msg do
    require_app('lib', config: false)

    puts "New MSG_KEY (base64): #{LockedCV::SecureMessage.generate_key}"
  end
end
