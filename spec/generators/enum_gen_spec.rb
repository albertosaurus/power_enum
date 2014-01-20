require 'spec_helper'

describe :enum do

  def generate_migration(enum_name, &block)
    GenerateMigrationMatcher.new(enum_name, &block)
  end

  context 'no arguments or options' do
    it 'should generate an error message' do
      subject.should output("No value provided for required arguments 'name'")
    end
  end

  with_args :foo do
    it 'should generate enum model' do
      class_contents = <<-exp
class Foo < ActiveRecord::Base
  acts_as_enumerated
end
      exp

      subject.should generate('app/models/foo.rb') { |content|
        content.should eq(class_contents)
      }
    end

    it 'should generate migration' do
      migration_contents = <<-exp
class CreateEnumFoo < ActiveRecord::Migration

  def change
    create_enum :foo
  end

end
      exp

      subject.should generate_migration(:foo) { |content|
        content.should eq(migration_contents)
      }
    end
  end
end
