require 'spec_helper'

describe PowerEnum::Reflection::EnumerationReflection do
  it 'should add reflection via reassigning reflections hash' do
    Booking.reflections.object_id.should_not == Adapter.reflections.object_id
  end

  context 'Booking should have a reflection for each enumerated attribute' do

    [:state, :status].each do |enum_attr|
      it "should have a reflection for #{enum_attr}" do
        reflection = Booking.reflections[enum_attr]
        reflection.should_not be_nil
        reflection.chain.should =~ [reflection]
        reflection.check_validity!
        reflection.source_reflection.should be_nil
        reflection.conditions.should == [[]]
        reflection.type.should be_nil
        reflection.source_macro.should == :belongs_to
        reflection.belongs_to?.should be_true
      end
    end

    it 'should have the correct table name' do
      Booking.reflections[:state].table_name.should == 'states'
      Booking.reflections[:status].table_name.should == 'booking_statuses'
    end
  end

  context 'joins' do
    before :each do
      [:confirmed, :received, :rejected].map{|status|
        booking = Booking.create(:status => status)
        booking
      }
    end

    after :each do
      Booking.destroy_all
    end

    it 'should build a valid join' do
      bookings = Booking.joins(:status)
      bookings.size.should == 3
    end

    it 'should allow conditions on joined tables' do
      bookings = Booking.joins(:status).where(:booking_statuses => {:name => :confirmed})
      bookings.size.should == 1
      bookings.first.status.should == BookingStatus[:confirmed]
    end
  end
end