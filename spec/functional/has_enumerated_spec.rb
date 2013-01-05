require 'spec_helper'

describe 'has_enumerated' do
  before(:each) do
    Booking.destroy_all
    @booking = Booking.create
  end

  it 'provides #status method' do
    @booking.should respond_to :status
  end

  it 'provides #status= method' do
    @booking.should respond_to :status=
  end

  it 'has_enumerated? should respond true to enumerated attributes' do
    Booking.has_enumerated?(:state).should be_true
    Booking.has_enumerated?('status').should be_true
    Booking.has_enumerated?('foo').should_not be_true
    Booking.has_enumerated?(nil).should_not be_true
  end

  it 'should be able to reflect on all enumerated' do
    Booking.should respond_to(:reflect_on_all_enumerated)
    Booking.reflect_on_all_enumerated.map(&:name).to_set.should == [:state, :status].to_set
  end

  it 'should include enumerations as associations' do
    Booking.reflect_on_all_associations.map(&:name).to_set.should == [:state, :status].to_set
  end

  it 'should have reflection on has_enumerated association' do
    Booking.reflect_on_enumerated(:state).should_not be_nil
    Booking.reflect_on_enumerated('status').should_not be_nil
  end

  it 'should have reflection on association' do
    Booking.reflect_on_association(:state).should_not be_nil
    Booking.reflect_on_association('status').should_not be_nil
  end

  it 'should have reflection properly built' do
    reflection = Booking.reflect_on_enumerated(:status)
    reflection.should be_kind_of(PowerEnum::Reflection::EnumerationReflection)
    reflection.macro.should == :has_enumerated
    reflection.name.to_sym.should == :status
    reflection.active_record.should == Booking
    reflection.klass.should == BookingStatus
    reflection.options[:foreign_key].should == :status_id
    reflection.options[:on_lookup_failure].should == :not_found_status_handler
  end

  it 'enumerated_attributes should contain the list of has_enumerated attributes and nothing else' do
    Booking.enumerated_attributes.size.should == 2
    ['state', 'status'].each do |s|
      Booking.enumerated_attributes.should include(s)
    end
  end

  it 'A has_enumerated attribute without a :default option should have a default value of null' do
    Booking.new.status.should be_nil
  end

  it 'A has_enumerated attribute with a :default option should have the default value passed to has_enumerated' do
    Booking.new.state.should == State[:FL]
  end

  context 'enumerated attribute scope' do

    before :each do
      [:confirmed, :received, :rejected].map{|status|
        booking = Booking.create(:status => status)
        booking
      }
    end

    after :each do
      Booking.destroy_all
    end

    it 'should create a scopes for the enumerated attribute by default' do
      Booking.should respond_to(:with_status)
      Booking.should respond_to(:exclude_status)
    end

    it "should properly alias the plural version of the scope" do
      Booking.should respond_to(:with_statuses)
      Booking.should respond_to(:exclude_statuses)
    end

    it 'should not create a scope if the "create_scope" option is set to false' do
      Booking.should_not respond_to(:with_state)
      Booking.should_not respond_to(:with_states)
      Booking.should_not respond_to(:exclude_state)
      Booking.should_not respond_to(:exclude_states)
    end

    it 'the generated scope should work with ids, strings, symbols, and enum instances' do
      sql = [
        [1, 3],
        [:confirmed, :rejected],
        ['confirmed', 'rejected'],
        [BookingStatus[1], BookingStatus[3]]
      ].map{ |status1, status2|
        Booking.with_status(status1, status2).to_sql
      }
      sql.each{|s|
        sql.first.should == s
      }
    end

    it 'should only fetch the specified bookings' do
      bookings = Booking.with_status(:received, :rejected)
      bookings.size.should == 2
      bookings.find{ |booking| booking.status == BookingStatus[:received] }.should_not be_nil
      bookings.find{ |booking| booking.status == BookingStatus[:rejected] }.should_not be_nil

      bookings2 = Booking.with_statuses(:received, :rejected)
      bookings2.size.should == 2
      bookings2.should == bookings
    end

    it 'exclude scope should filter out given booking statuses' do
      bookings = Booking.exclude_statuses(:received, :confirmed)
      bookings.size.should == 1
      bookings.first.status.should ==  BookingStatus[:rejected]
    end

  end

  context 'when enum value exists' do
    it 'assigns and returns an appropriate status model when Symbol is passed' do
      @booking.status = :confirmed
      status = @booking.status
      status.should_not be_new_record
      status.should be_an_instance_of BookingStatus
      status.name.should == 'confirmed'
    end

    it 'assigns and returns an appropriate status when String is passed' do
      @booking.status = 'confirmed'
      status = @booking.status
      status.should_not be_new_record
      status.should be_an_instance_of BookingStatus
      status.name.should == 'confirmed'
    end

    it 'assigns and returns an appropriate status when Fixnum is passed' do
      @booking.status = 1
      status = @booking.status
      status.should_not be_new_record
      status.should be_an_instance_of BookingStatus
      status.name.should == 'confirmed'
    end

    it 'correctly looks up the proper value from the enumeration cache when performing update_attributes' do
      @booking.update_attributes(:status => :rejected)
      status = @booking.status
      status.should_not be_new_record
      status.should be_an_instance_of BookingStatus
      status.name.should == 'rejected'
    end
  end

  context 'when enum value does not exist' do

    context ':on_lookup_failure method is specified' do

      it 'calls :on_lookup_failure method on assigning' do
        @booking.should_receive(:not_found_status_handler).
            with(:write, 'status', 'status_id', 'BookingStatus', 'bad_status')
        @booking.status = 'bad_status'
      end

      it 'does not call :on_lookup_failure method on assignment when nil is passed' do
        @booking.should_receive(:status_id=).with(nil)
        @booking.status = nil
      end

      it 'does not call :on_lookup_failure method on assignment when empty string is passed, converting it to nil' do
        @booking.should_receive(:status_id=).with(nil)
        @booking.status = ''
      end

      it 'adds "is invalid" validation error if :on_lookup_failure method is set to "validation_error"' do
        @booking.state = :XXX
        @booking.should be_invalid
        @booking.errors.messages[:state].should == ["is invalid"]
        @booking.state.should == :XXX

        @booking.state = :IL
        @booking.valid?
        @booking.should be_valid
        @booking.state.should == State[:IL]
      end

      it 'assigns the foreign key to nil if :on_lookup_failure method is specified and nil or empty string is passed' do
        @booking.status = :confirmed
        @booking.status = nil
        @booking.status.should be_nil
        @booking.status = ''
        @booking.status.should be_nil
      end

      it 'adds "is invalid" validation error if :on_lookup_failure method is  is set to "validation_error" and empty string is passed and :permit_empty_name is set' do
        @booking.state = ''
        @booking.should be_invalid
        @booking.errors.messages[:state].should == ["is invalid"]
        @booking.state.should == ''
      end

    end

    context ':on_lookup_failure lambda' do
      it 'should call the lambda expression' do
        widget = Widget.new
        widget.connector_type=(:foobarbaz)
        res = widget.lookup
        res[0].should == widget
        res[1].should == :write
        res[2].should == 'connector_type'
        res[3].should == 'connector_type_id'
        res[4].should == 'ConnectorType'
        res[5].should == :foobarbaz
      end
    end

    context ':on_lookup_failure not specified' do

      let(:adapter){ Adapter.new }

      it 'should raise ArgumentError if given invalid value' do
        expect{
          adapter.connector_type = :foo
        }.to raise_error(ArgumentError)
      end

      it 'assigns the foreign key to nil if nil is passed' do
        adapter.connector_type = nil
        adapter.connector_type.should == nil
        adapter.connector_type_id.should == nil
      end

      it 'converts empty strings to nil and nils out the foreign key' do
        adapter.connector_type = ''
        adapter.connector_type.should == nil
        adapter.connector_type_id.should == nil
      end
    end

  end

  context 'reflections' do
    it 'should add reflection via reassigning reflections hash' do
      Booking.reflections.object_id.should_not == Adapter.reflections.object_id
    end
  end
end
