require "rake"

desc "Run specs"
task :default do
  begin
    ENV['RACK_ENV'] = 'test'
    sh "echo -n '' > unicorn.test.log"
    sh "#{FileUtils::RUBY} -S unicorn -p 8989 -c unicorn.test.conf -D" if RUBY_VERSION > '1.9'
    sh "#{FileUtils::RUBY} -S spec unit_test.rb"
    sh "#{FileUtils::RUBY} -S spec test.rb"
    sh "#{FileUtils::RUBY} -S spec test_ajax.rb" if RUBY_VERSION > '1.9'
  ensure
    sh "kill `cat unicorn.test.pid`" if RUBY_VERSION > '1.9'
  end
end

namespace :assets do
  desc "Precompile the assets"
  task :precompile do
    require './spam'
    Spam.compile_assets
  end
end
