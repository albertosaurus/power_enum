require 'spec_helper' 
# BookingStatus and State models act as enumarated.
# All predefined booking statuses are in "add_booking_statuses" migration.
#
describe 'acts_as_enumerated' do

  it 'reponds to []' do
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
	end

	it 'returns a record found by name if Symbol is passed' do
	  status = BookingStatus[:confirmed]
	  status.should be_an_instance_of BookingStatus
	  status.name.should == 'confirmed'
	end

	it 'returns a record found by id when Fixnum is passed' do
	  status = BookingStatus[1]
	  status.should be_an_instance_of BookingStatus
	  status.name.should == 'confirmed'
	end
      end

      context ':name_column is specified' do
	it 'returns a record found by name if String is passed' do
	  state = State['IL']
	  state.should be_an_instance_of State
	  state.state_code.should == 'IL'
	end

	it 'returns a record found by name if Symbol is passed' do
	  state = State[:IL]
	  state.should be_an_instance_of State
	  state.state_code.should == 'IL'
	end

	it 'returns a record found by id when Fixnum is passed' do
	  state = State[1]
	  state.should be_an_instance_of State
	  state.state_code.should == 'IL'
	end

      end
    end


    context 'record does not exist' do
      context ':on_lookup_failure is specified' do
	it 'if :on_lookup_failure is passed calls the speicified class method' do
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
end
