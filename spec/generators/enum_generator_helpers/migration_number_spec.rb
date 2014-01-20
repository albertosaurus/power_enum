require 'spec_helper'

require File.expand_path('../../../../lib/generators/enum/enum_generator_helpers/migration_number', __FILE__)

class MigrationStub
  include EnumGeneratorHelpers::MigrationNumber
end

describe EnumGeneratorHelpers::MigrationNumber do
  let(:helper) { MigrationStub.new }
  let(:dirname) { "#{Rails.root}/db/migrate/[0-9]*_*.rb" }

  it 'non-timestamp migration number' do
    helper.should_receive(:current_migration_number).and_return(5)
    ActiveRecord::Base.should_receive(:timestamped_migrations).and_return(false)

    helper.next_migration_number(dirname).should eq('006')
  end

  it 'timestamp migration number' do
    helper.should_receive(:current_migration_number).and_return(90000000000001)

    helper.next_migration_number(dirname).should eq('90000000000002')
  end
end
