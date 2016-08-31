require 'spec_helper'

describe PowerEnum::Reflection::EnumerationReflection do
  it 'should add reflection via reassigning reflections hash' do
    Booking.reflections.object_id.should_not == Adapter.reflections.object_id
  end

  context 'Booking should have a reflection for each enumerated attribute' do

    [:state, :status].each do |enum_attr|
      it "should have a reflection for #{enum_attr}" do
        refl = if Rails.version =~ /^4\.2.*/ || Rails.version =~ /5.*/
                 enum_attr.to_s
               else
                 enum_attr
               end
        reflection = Booking.reflections[refl]
        Booking.reflect_on_enumerated(enum_attr).should == reflection

        reflection.should_not be_nil
        reflection.chain.should =~ [reflection]
        reflection.check_validity!
        reflection.source_reflection.should be_nil
        reflection.conditions.should == [[]]
        reflection.type.should be_nil
        reflection.source_macro.should == :belongs_to
        reflection.belongs_to?.should eq(true)
        reflection.name.to_sym.should == enum_attr
        reflection.active_record.should == Booking
        reflection.should respond_to(:counter_cache_column)
        reflection.macro.should == :has_enumerated
        reflection.should be_kind_of(PowerEnum::Reflection::EnumerationReflection)
      end
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
      reflection.klass.should == BookingStatus
      reflection.options[:foreign_key].should == :status_id
      reflection.options[:on_lookup_failure].should == :not_found_status_handler
    end

    it 'should have the correct table name' do
      if Rails.version =~ /^4\.2.*/ || Rails.version =~ /5.*/
        Booking.reflections['state'].table_name.should == 'states'
        Booking.reflections['status'].table_name.should == 'booking_statuses'
      else
        Booking.reflections[:state].table_name.should == 'states'
        Booking.reflections[:status].table_name.should == 'booking_statuses'
      end
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
