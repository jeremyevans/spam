require "rake"

default_specs = [:spec, :integration]
default_specs << :ajax if RUBY_VERSION > '2.3'
desc "Run the unit and integration specs"
task :default=>default_specs

desc "Run unit tests"
task :spec do
  sh "#{FileUtils::RUBY} unit_test.rb"
end

desc "Run integration tests"
task :integration do
  sh "#{FileUtils::RUBY} test.rb"
end

desc "Run ajax tests"
task :ajax do
  begin
    ENV['RACK_ENV'] = 'test'
    sh "echo -n '' > unicorn.test.log"
    unicorn_bin = File.basename(FileUtils::RUBY).sub(/\Aruby/, 'unicorn')
    sh "#{FileUtils::RUBY} -S #{unicorn_bin} -p 8989 -c unicorn.test.conf -D"
    Rake::Task['_ajax'].invoke
  ensure
    sh "kill `cat unicorn.test.pid`"
  end
end

task :_ajax do
  sh "#{FileUtils::RUBY} test_ajax.rb"
end

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require './spam'
    Spam::App.compile_assets
  end
end
