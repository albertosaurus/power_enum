require 'spec_helper'
# BookingStatus and State models act as enumerated.
# All predefined booking statuses are in "add_booking_statuses" migration.
#
describe 'acts_as_enumerated' do

  it 'responds to []' do
    BookingStatus.should respond_to :[]
    State.should respond_to :[]
  end


  describe '[]' do

    context 'record exists' do
      context ':name_column is not specified (using :name by default)' do
        it 'returns a record found by name if String is passed' do
          status = BookingStatus['confirmed']
          status.should be_an_instance_of BookingStatus
          status.name.should == 'confirmed'
          status.name_sym.should == :confirmed
        end

        it 'returns a record found by name if Symbol is passed' do
          status = BookingStatus[:confirmed]
          status.should be_an_instance_of BookingStatus
          status.name.should == 'confirmed'
          status.name_sym.should == :confirmed
        end

        it 'returns a record found by id when Fixnum is passed' do
          status = BookingStatus[1]
          status.should be_an_instance_of BookingStatus
          status.name.should == 'confirmed'
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
    end
  end

  describe 'in?' do
    it 'in? should find by Symbol, String, or Fixnum' do
      [1, :IL, 'IL'].each do |arg|
        State[:IL].in?(arg).should == true
      end
    end
  end

  describe 'name' do
    context ':name_column is not specified' do
      it 'name should return value of "name" attribute' do
        BookingStatus[:confirmed].name.should == 'confirmed'
      end
    end

    context ':name_column is specified to be :state_code' do
      it 'name should return value of the "name_column" attribute' do
        State[:IL].name.should == 'IL'
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

  specify "#to_s" do
    BookingStatus[:confirmed].to_s.should == 'confirmed'
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
        con.name.should == expected[index]
      end
    end
  end
end
