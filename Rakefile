require "rake"

begin
  begin
    # RSpec 2+
    require "rspec/core/rake_task"
    spec_class = RSpec::Core::RakeTask
    spec_files_meth = :pattern=
  rescue LoadError
    # RSpec 1
    require "spec/rake/spectask"
    spec_class = Spec::Rake::SpecTask
    spec_files_meth = :spec_files=
  end

  default_specs = [:spec, :integration]
  default_specs << :ajax if RUBY_VERSION > '1.9'
  desc "Run the unit and integration specs"
  task :default=>default_specs

  desc "Run unit tests"
  spec_class.new("spec") do |t|
    t.send spec_files_meth, ["unit_test.rb"]
  end

  desc "Run integration tests"
  spec_class.new("integration") do |t|
    t.send spec_files_meth, ["test.rb"]
  end

  desc "Run ajax tests"
  task :ajax do
    begin
      ENV['RACK_ENV'] = 'test'
      sh "echo -n '' > unicorn.test.log"
      sh "#{FileUtils::RUBY} -S unicorn -p 8989 -c unicorn.test.conf -D"
      Rake::Task['_ajax'].invoke
    ensure
      sh "kill `cat unicorn.test.pid`"
    end
  end

  spec_class.new("_ajax") do |t|
    t.send spec_files_meth, ["test_ajax.rb"]
  end
rescue LoadError
  task :default do
    puts "Must install rspec to run the default task (which runs specs)"
  end
end

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require './spam'
    Spam.compile_assets
  end
end
