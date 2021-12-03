require "rake"

default_specs = [:spec, :integration]

desc "Run unit tests"
task :spec do
  sh "#{FileUtils::RUBY} unit_test.rb"
end

desc "Run integration tests"
task :integration do
  sh "#{FileUtils::RUBY} test.rb"
end

default_specs << :ajax if RUBY_VERSION > '2.7'
desc "Run ajax tests"
task :ajax do
  begin
    ENV['RACK_ENV'] = 'test'
    ENV['AJAX_TESTS'] = '1'
    ENV['SPAM_SESSION_SECRET'] = '1'*64
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

desc "Run the unit and integration specs"
task :default=>default_specs

desc "Find unused associations and association methods"
task :unused_associations do
  ENV['UNUSED_ASSOCIATION_COVERAGE'] = '1'
  sh %{#{FileUtils::RUBY} unused_associations_coverage.rb unit_test.rb}
  sh %{#{FileUtils::RUBY} unused_associations_coverage.rb test.rb}
  Rake::Task['ajax'].invoke

  require './models'
  Spam::Model.update_unused_associations_data

  puts "Unused Associations:"
  Spam::Model.unused_associations.each do |sc, assoc|
    puts "#{sc}##{assoc}"
  end

  puts "Unused Associations Options:"
  Spam::Model.unused_association_options.each do |sc, assoc, options|
    options.delete(:no_dataset_method)
    next if options.empty?
    puts "#{sc}##{assoc}: #{options.inspect}"
  end
  Spam::Model.delete_unused_associations_files
end

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    ENV["ASSETS_PRECOMPILE"] = '1'
    require './spam'
    Spam::App.compile_assets
  end
end

desc "Annotate Sequel models"
task "annotate" do
  ENV['RACK_ENV'] = 'development'
  require_relative 'models'
  require 'sequel/annotate'
  Sequel::Annotate.annotate(Dir['models/*.rb'], :namespace=>true)
end
