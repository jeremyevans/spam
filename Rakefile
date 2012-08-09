require "rake"

task :default do
  begin
    ENV['RAILS_ENV'] = 'test'
    sh "echo -n '' > log/rails.test.log"
    sh "echo -n '' > log/unicorn.test.log"
    sh "#{FileUtils::RUBY} -S unicorn -p 8989 -c config/unicorn.test.conf -D"
    sh "#{FileUtils::RUBY} -S spec unit_test.rb"
    sh "#{FileUtils::RUBY} -S spec test.rb"
  ensure
    sh "kill `cat log/unicorn.test.pid`"
  end
end
