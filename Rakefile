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
    require 'base64'
    require 'rbnacl'

    puts "New SESSION_SECRET (base64): #{Base64.urlsafe_encode64(RbNaCl::Random.random_bytes(64))}"
  end
end
