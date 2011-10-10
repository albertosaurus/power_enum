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
  
  it 'should have reflection on has_enumerated association' do
    Booking.reflect_on_enumerated(:state).should_not be_nil
    Booking.reflect_on_enumerated('status').should_not be_nil
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

  context 'when status exists' do
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
  end

  context 'when status does not exist' do
    it 'calls :on_lookup_failure method on assigning' do
      @booking.should_receive(:not_found_status_handler).
          with(:write, 'status', 'status_id', 'BookingStatus', 'bad_status')
      @booking.status = 'bad_status'
    end

    it 'does not call :on_lookup_failure method on assignment when nil is passed' do
      @booking.should_receive(:status_id=).with(nil)
      @booking.status = nil
    end

    it 'raises ArgumentError if :on_lookup_failure method is not specified' do
      expect { @booking.state = :XXX }.to raise_error ArgumentError
    end

    it 'assigns the foreign key to nil if :on_lookup_failure method is not specified and nil or empty string is passed' do
      @booking.status = :confirmed
      @booking.status = nil
      @booking.status.should be_nil
      @booking.status = ''
      @booking.status.should be_nil
    end
  end

end
