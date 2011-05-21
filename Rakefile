require 'rubygems'
require 'rspec/core/rake_task'
require 'active_record'
require 'active_support'
require 'yaml'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :db do
  task :load_config do
    ActiveRecord::Base.configurations = YAML.load(File.open('database.yml'))
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations)
  end

  desc 'Create the database'
  task :create => :load_config do
    create_database(ActiveRecord::Base.configurations)
  end

  def create_database(config)
    if File.exist? config['database']
      $stderr.puts "#{config['database']} already exists"
      return 
    end
    ActiveRecord::Base.connection
  end

  desc 'Drop the database'
  task :drop => :load_config do
    begin
      config = ActiveRecord::Base.configurations
      drop_database(config)
    rescue Exception => e
      $stderr.puts "Couldn't drop #{config['database']} : #{e.inspect}"
    end
  end
  
  def drop_database(config)
    FileUtils.rm(config['database'])
  end

  desc 'Migrate the database'
  task :migrate => :load_config do
    ActiveRecord::Migrator.migrate('db/migrate')
  end

  namespace :migrate do
    desc 'Reset the database'
    task :reset => ["db:drop", "db:create", "db:migrate"]
  end
end
