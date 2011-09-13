begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.name = "enumerations_mixin"
    gem.summary = "Allows you to treat instances of your ActiveRecord models as though they were an enumeration of values"
    gem.description = "Allows you to treat instances of your ActiveRecord models as though they were an enumeration of values"
    gem.email = "pivotal-opensource@googlegroups.com"
    gem.homepage = "http://github.com/pivotal/enumerations_mixin"
    gem.authors = ["Trevor Squires", "Pivotal Labs"]
    gem.files = Dir["{lib}/**/*"] + Dir["{examples}/**/*"]
    gem.add_dependency "rails", '~> 3.0.0'
  end
rescue
  puts "Jeweler or one of its dependencies is not installed."
end


begin
  require 'rspec/core/rake_task'
  task :default => :spec

  RSpec::Core::RakeTask.new do |t|
    t.rspec_opts = ['--color', '--backtrace', '--format nested']
  end
rescue
  puts "rspec gem is not installed"
end

