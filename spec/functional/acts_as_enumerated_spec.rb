require 'spec_helper'
# BookingStatus and State models act as enumerated.
# All predefined booking statuses are in "add_booking_statuses" migration.
#
describe 'acts_as_enumerated' do

  it 'responds to []' do
    BookingStatus.should respond_to :[]
    State.should respond_to :[]
  end

  describe 'all_by_name' do

    def flush_cache(klass)
      tmp = klass.enumeration_model_updates_permitted
      begin
        klass.enumeration_model_updates_permitted = true
        klass.purge_enumerations_cache

        yield klass
        BookingStatus.should_receive(:name_column).twice.and_return('name_column')
        BookingStatus.should_receive(:all_by_attribute).and_raise(NoMethodError.new('foo', 'name_column'))
        expect{
          BookingStatus.send(:all_by_name)
        }.to raise_error(TypeError)
      ensure
        klass.purge_enumerations_cache
        klass.enumeration_model_updates_permitted = tmp
      end
    end

    it 'should raise a TypeError if the name column is not defined' do
      flush_cache(BookingStatus) do |klass|
        klass.should_receive(:name_column).twice.and_return('name_column')
        klass.should_receive(:all_by_attribute).and_raise(NoMethodError.new('foo', 'name_column'))
        expect{
          klass.send(:all_by_name)
        }.to raise_error(TypeError)
      end
    end

    it 'should raise NoMethodError for any unrelated NoMethodError' do
      flush_cache(BookingStatus) do |klass|
        klass.should_receive(:name_column).and_return('name_column')
        klass.should_receive(:all_by_attribute).and_raise(NoMethodError.new('foo', 'foo'))
        expect{
          klass.send(:all_by_name)
        }.to raise_error(NoMethodError)
      end
    end
  end

  describe 'purge_enumerations_cache' do
    it 'should raise a runtime error unless enumeration model updates are permitted' do
      tmp = BookingStatus.enumeration_model_updates_permitted
      begin
        BookingStatus.enumeration_model_updates_permitted = false
        expect{
          BookingStatus.purge_enumerations_cache
        }.to raise_error(RuntimeError)
      ensure
        BookingStatus.enumeration_model_updates_permitted = tmp
      end
    end
  end

  describe 'enforce' do
    {
        :enforce_strict_literals => :foo,
        :enforce_strict_ids => 1,
        :enforce_strict_symbols => :foo
    }.each_pair do |method, argument|
      it "should raise ActiveRecord::RecordNotFound when #{method} is called" do
        expect{
          BookingStatus.send(method, argument)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '[]' do

    context 'record exists' do
      context ':name_column is not specified (using :name by default)' do
        it 'returns a record found by name if String is passed' do
          status = BookingStatus['confirmed']
          status.should be_an_instance_of BookingStatus
          status.__enum_name__.should == 'confirmed'
          status.name_sym.should == :confirmed
        end

        it 'returns a record found by name if Symbol is passed' do
          status = BookingStatus[:confirmed]
          status.should be_an_instance_of BookingStatus
          status.__enum_name__.should == 'confirmed'
          status.name_sym.should == :confirmed
        end

        it 'returns a record found by id when Fixnum is passed' do
          status = BookingStatus[1]
          status.should be_an_instance_of BookingStatus
          status.__enum_name__.should == 'confirmed'
          status.name_sym.should == :confirmed
        end

      end

      context ':name_column is specified' do
        it 'returns a record found by name if String is passed' do
          state = State['IL']
          state.should be_an_instance_of State
          state.state_code.should == 'IL'
          state.name_sym.should == :IL
        end

        it 'returns a record found by name if Symbol is passed' do
          state = State[:IL]
          state.should be_an_instance_of State
          state.state_code.should == 'IL'
          state.name_sym.should == :IL
        end

        it 'returns a record found by id when Fixnum is passed' do
          state = State[1]
          state.should be_an_instance_of State
          state.state_code.should == 'IL'
          state.name_sym.should == :IL
        end

      end

      context 'multiple arguments to []' do
        it 'should look up multiple values' do
          states = State[:IL, 'WI']
          states.size.should == 2
          states.first.should == State[:IL]
          states.last.should == State[:WI]
        end

        it 'should handle nils' do
          states = State[nil, :IL]
          states.size.should == 2
          states.first.should == nil
          states.last.should == State[:IL]
        end

        it 'should filter out duplicates' do
          states = State[:IL, :IL]
          states.size.should == 1
          states.first.should == State[:IL]
        end
      end
    end

    context 'record does not exist' do
      context ':on_lookup_failure is specified' do
        it 'if :on_lookup_failure is passed calls the specified class method' do
          BookingStatus.should_receive(:not_found).with(:bad_status)
          BookingStatus[:bad_status]
        end
      end

      context ':on_lookup_failure is not specified' do
        it 'returns nil if String is passed' do
          State['XXX'].should be_nil
        end

        it 'raises if Symbol passed' do
          expect { State[:XXX] }.to raise_error ActiveRecord::RecordNotFound
        end

        it 'raises if Fixnum is passed' do
          expect { State[999_999] }.to raise_error ActiveRecord::RecordNotFound
        end

        it 'handles multiple args to []' do
          states = State['XXX', 'IL']
          states.size.should == 2
          states.first.should be_nil
          states.last.should == State[:IL]

          State['XXX', 'XXX'].size.should == 1

          expect{ State[999, 'IL'] }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context ':on_lookup_failure is a lambda' do
        it 'should call the defined lambda' do
          Color[:foo].should == :foo
          Color[nil].should == :bar
        end
      end
    end

    it 'returns instance when instance is passed' do
      state = State[1]
      state2 = State[state]
      state2.should == state
    end

  end # describe '[]'

  describe 'contains?' do

    context 'item exists' do

      context ':name_column is not explicitly specified' do

        it 'returns true if looking up String' do
          BookingStatus.contains?('confirmed').should be_true
        end

        it 'returns true if looking up by Symbol' do
          BookingStatus.contains?(:confirmed).should be_true
        end

        it 'returns true if looking up by id' do
          BookingStatus.contains?(1).should be_true
        end

        it 'return true if passing in an enum instance' do
          BookingStatus.contains?(BookingStatus.all.first).should be_true
        end

      end # context ':name_column is not explicitly specified'

      context ':name_column is specified' do

        it 'returns true if looking up String' do
          State.contains?('IL').should be_true
        end

        it 'returns true if looking up by Symbol' do
          State.contains?(:IL).should be_true
        end

        it 'returns true if looking up by id' do
          State.contains?(1).should be_true
        end

        it 'return true if passing in an enum instance' do
          State.contains?(State.all.first).should be_true
        end
      end # context ':name_column is specified'

    end # context 'item exists'

    context 'item does not exist' do

      it 'returns false when passing in a nil' do
        BookingStatus.contains?(nil).should be_false
      end

      it 'returns false when passing in a random value' do
        BookingStatus.contains?(Booking.new).should be_false
      end

      it 'returns false when a lookup by id fails' do
        State.contains?(999999).should be_false
      end

      it 'returns false when a lookup by Symbol fails' do
        State.contains?(:XXX).should be_false
      end

      it 'returns false when a lookup by String fails' do
        State.contains?('XXX').should be_false
      end
    end
  end

  describe '===' do
    context ':name_column is not specified and on_lookup_failure defined' do

      it '=== should match correct string' do
        BookingStatus[:confirmed].should === 'confirmed'
      end

      it '=== should match correct symbol' do
        BookingStatus[:confirmed].should === :confirmed
      end

      it '=== should match correct id' do
        BookingStatus[:confirmed].should === 1
      end

      it '=== should reject incorrect string' do
        BookingStatus[:confirmed].should_not === 'foo'
      end

      it '=== should reject incorrect symbol' do
        BookingStatus[:confirmed].should_not === :foo
      end

      it '=== should reject incorrect id' do
        BookingStatus[:confirmed].should_not === 2
      end

      it '=== should reject nil' do
        BookingStatus[:confirmed].should_not === nil
      end

      it '=== should match if a member of the array matches' do
        BookingStatus[:confirmed].should === [:confirmed, :foo]
      end

      it '=== should reject if no member of the array matches' do
        BookingStatus[:confirmed].should_not === [:baz, :bar, :foo]
      end

      it '=== should reject random garbage' do
        BookingStatus[:confirmed].should_not === 2.5
      end

    end

    context ':name_column is specified and on_lookup_failure defined as enforce_strict_literals' do

      it '=== should match correct string' do
        State[:IL].should === 'IL'
      end

      it '=== should match correct symbol' do
        State[:IL].should === :IL
      end

      it '=== should match correct id' do
        State[:IL].should === 1
      end

      it '=== should reject incorrect string' do
        State[:IL].should_not === 'foo'
      end

      it '=== should raise if Symbol is compared' do
        State[:IL].should_not === 'foo'
      end

      it '=== should reject nil' do
        State[:IL].should_not === nil
      end

      it '=== should match if a member of the array matches' do
        State[:IL].should === [:IL, :foo]
      end

      it '=== should reject if no member of the array matches' do
        State[:IL].should_not === [nil, nil, nil]
      end

      it '=== should reject random garbage' do
        State[:IL].should_not === 2.5
      end

    end
  end

  describe 'name' do
    it 'should create a name alias by default' do
      State[:IL].respond_to?(:name).should be_true
    end

    it 'should not create a name alias if :name_alias is set to false' do
      Fruit[:apple].respond_to?(:name).should be_false
    end

    specify "#name" do
      BookingStatus[:confirmed].name.should == 'confirmed'
      State[:IL].name.should == 'IL'
    end
  end

  describe 'in?' do
    it 'in? should find by Symbol, String, or Fixnum' do
      [1, :IL, 'IL'].each do |arg|
        State[:IL].in?(arg).should be_true
      end
    end

    it 'in? should return false if nothing matches' do
      State[:IL].in?(nil).should be_false
    end
  end

  describe '__enum_name__' do
    context ':name_column is not specified' do
      it '__ should return value of "name" attribute' do
        BookingStatus[:confirmed].__enum_name__.should == 'confirmed'
      end
    end

    context ':name_column is specified to be :state_code' do
      it '__enum_name__ should return value of the "name_column" attribute' do
        State[:IL].__enum_name__.should == 'IL'
      end
    end
  end

  describe 'name_sym' do
    context ':name_column is not specified' do
      it 'name_sym should equal the value in the name column cast to a symbol' do
        BookingStatus[:confirmed].name_sym.should == :confirmed
      end
    end

    context ':name_column is specified to be :state_code' do
      it 'name_sym should equal value in the column defined under :name_column cast to a symbol' do
        State[:IL].name_sym.should == :IL
      end
    end
  end

  describe 'to_sym' do

    it 'to_sym should alias to name_sym' do
      State.all.each{ |st| st.to_sym.should == st.name_sym }
    end

  end

  specify "#to_s" do
    BookingStatus[:confirmed].to_s.should == 'confirmed'
    State[:IL].to_s.should == 'IL'
  end

  describe 'name_column' do
    context ':name_column is not specified' do
      it 'name_column should be :name' do
        BookingStatus.name_column.should == :name
      end
    end

    context ':name_column is specified to be :state_code' do
      it 'name_column should be :state_code' do
        State.name_column.should == :state_code
      end
    end
  end

  describe 'include?' do
    it 'include? should find by id, Symbol, String, and self' do
      [State[:IL].id, State[:IL], :IL, 'IL'].each do |val|
        State.include?(val).should == true
      end
    end

    it 'include? should reject nil' do
      State.include?(nil).should == false
    end
  end

  describe 'validations' do
    before :each do
      BookingStatus.enumeration_model_updates_permitted = false
    end

    it 'Should not permit the creation of new enumeration models by default' do
      bs = BookingStatus.create(:name => 'unconfirmed')
      bs.new_record?.should == true
      bs.save.should == false
    end

    it 'Should not permit the creation of an enumeration model with a blank name' do
      BookingStatus.enumeration_model_updates_permitted = true
      bs = BookingStatus.create()
      bs.new_record?.should == true
      bs.valid?.should == false
      bs.errors[:name].first.should == "can't be blank"
      bs.save.should == false
    end

    it 'Should not permit the creation of an enumeration model with a duplicate name' do
      BookingStatus.enumeration_model_updates_permitted = true
      bs = BookingStatus.create(:name => 'confirmed')
      bs.new_record?.should == true
      bs.valid?.should == false
      bs.errors[:name].first.should == 'has already been taken'
      bs.save.should == false
    end
  end

  describe 'active' do
    context "no 'active' column" do
      it 'all and active should be the equal, i.e. contain all enums' do
        BookingStatus.active.should == BookingStatus.all
      end

      it 'inactive should be empty' do
        BookingStatus.inactive.should be_empty
      end

      it 'each enum should be active' do
        BookingStatus.all.each do |booking_status|
          booking_status.active?.should == true
          booking_status.inactive?.should == false
        end
      end
    end

    context "'active' column defined" do
      it 'active should only include active enums' do
        ConnectorType.active.size.should == 2
        ConnectorType.active.should include(ConnectorType[:HDMI])
        ConnectorType.active.should include(ConnectorType[:DVI])
        ConnectorType.active.should_not include(ConnectorType[:VGA])
      end

      it 'inactive should only include inactive enums' do
        ConnectorType.inactive.size.should == 1
        ConnectorType.inactive.should_not include(ConnectorType[:HDMI])
        ConnectorType.inactive.should_not include(ConnectorType[:DVI])
        ConnectorType.inactive.should include(ConnectorType[:VGA])
      end
    end

    context "no 'active' column but 'active?' overriden" do
      it "all and active should have the same contents" do
        State.active.should == State.all
      end

      it "inactive should be empty" do
        State.inactive.should be_empty
      end
    end
  end

  describe 'order' do
    it 'connector types should be ordered by name in descending order' do
      expected = ['VGA', 'HDMI', 'DVI']
      ConnectorType.all.each_with_index do |con, index|
        con.__enum_name__.should == expected[index]
      end
    end
  end

  describe 'names' do
    it "should return the names of an enum as an array of symbols" do
      ConnectorType.names.should == [:VGA, :HDMI, :DVI]
    end

    it 'should return names if there is no :name alias' do
      Fruit.names.should == [:apple, :peach, :pear]
    end
  end

  describe 'update_enumerations_model' do

    it 'should not complain if no block given' do
      expect{
        ConnectorType.update_enumerations_model
      }.to_not raise_error
    end

    it 'should permit enumeration model updates and purge enumeration cache' do
      ConnectorType.update_enumerations_model do
        ConnectorType.create :name        => 'Foo',
                             :description => 'Bar',
                             :has_sound   => true
      end
      ConnectorType.all.size.should == 4
      ConnectorType['Foo'].should_not be_nil

      ConnectorType.update_enumerations_model do
        ConnectorType['Foo'].description = 'foobar'
        ConnectorType['Foo'].save!
      end
      ConnectorType['Foo'].description.should == 'foobar'

      ConnectorType.update_enumerations_model do
        ConnectorType['Foo'].destroy
      end
      ConnectorType.all.size.should == 3
      ConnectorType['Foo'].should be_nil
    end

    it 'should allow a block with an argument' do
      ConnectorType.update_enumerations_model do |klass|
        klass.create :name        => 'Foo',
                     :description => 'Bar',
                     :has_sound   => true
      end
      ConnectorType.all.size.should == 4
      ConnectorType['Foo'].should_not be_nil

      ConnectorType.update_enumerations_model do |klass|
        klass['Foo'].description = 'foobar'
        klass['Foo'].save!
      end
      ConnectorType['Foo'].description.should == 'foobar'

      ConnectorType.update_enumerations_model do |klass|
        klass['Foo'].destroy
      end
      ConnectorType.all.size.should == 3
      ConnectorType['Foo'].should be_nil
    end
  end

  describe 'acts_as_enumerated?' do
    it 'enum models should act as enumerated' do
      ConnectorType.acts_as_enumerated?.should == true
    end

    it 'models which are not enums should not act as enumerated' do
      Booking.acts_as_enumerated?.should == false
    end
  end

  context 'using class method as scopes' do
    before { State.enumeration_model_updates_permitted = true  }
    after  { State.enumeration_model_updates_permitted = false }

    it 'with .active method' do
      State.count.should == 3
      State.purge_enumerations_cache

      # .acitve may call redefined .all which caches only values with passed scope(not all)
      State.where(:state_code => "IL").active

      State.all.size.should == 3
    end

    it 'with .inactive method' do
      State.count.should == 3
      State.purge_enumerations_cache

      # .inacitve may call redefined .all which caches only values with passed scope(not all)
      State.where(:state_code => "IL").inactive

      State.all.size.should == 3
    end

  end
end
