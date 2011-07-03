require "rake"

task :default do
  sh 'spec unit_test.rb'
  sh 'spec19 unit_test.rb'
  sh 'run_tests.sh'
  ENV['RUBY'] = 'ruby19'
  sh 'run_tests.sh'
end

