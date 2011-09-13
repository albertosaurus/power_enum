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

  context 'when status does exists' do
    it 'calls :on_lookup_failure method on assigning' do
      @booking.should_receive(:not_found_status_handler).
	with(:write, 'status', 'status_id', 'BookingStatus', 'bad_status')
      @booking.status = 'bad_status'
    end

    it 'assings nil if :on_lookup_failure method is not specified' do
      @booking = Booking.create
      @booking.status = :XXX
      @booking.status.should be_nil
    end
  end

end
