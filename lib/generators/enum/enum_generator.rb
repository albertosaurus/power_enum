# Copyright (c) 2011 Arthur Shagall
# Released under the MIT license.  See LICENSE for details.

# Generator for PowerEnum
class EnumGenerator < Rails::Generators::NamedBase
  require File.expand_path('../enum_generator_helpers/migration_number', __FILE__)
  include Rails::Generators::Migration
  extend EnumGeneratorHelpers::MigrationNumber

  source_root File.expand_path('../templates', __FILE__)
  class_option :migration, :type => :boolean, :default => true, :desc => 'Generate migration for the enum'
  class_option :fixture, :type => :boolean, :default => false, :desc => 'Generate fixture for the enum'

  # Generates the enum ActiveRecord model.
  def generate_model
    template 'model.rb.erb', "app/models/#{file_name}.rb"
  end

  # Generates the migration to create the enum table.
  def generate_migration
    migration_template 'rails31_migration.rb.erb', "db/migrate/create_enum_#{table_name}.rb" if options.migration?
  end

  # Do not pluralize enumeration names
  def pluralize_table_names?
    false
  end

  hook_for :test_framework, :as => :model do |enum_generator_instance, test_generator_class|
    # Need to do this because I'm changing the default value of the 'fixture' option.
    table_name = enum_generator_instance.send(:table_name)
    enum_generator_instance.invoke( test_generator_class, [table_name], { 'fixture' => enum_generator_instance.options.fixture? } )
  end
end
