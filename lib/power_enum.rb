require "rails"

class PowerEnum < Rails::Engine
  config.autoload_paths << File.expand_path(File.join(__FILE__, "../"))

  initializer 'power_enum' do
    ActiveSupport.on_load(:active_record) do
      include ActiveRecord::Acts::Enumerated
      include ActiveRecord::Aggregations::HasEnumerated
      include PowerEnum::Reflection

      ActiveRecord::ConnectionAdapters.module_eval do
        include PowerEnum::Schema::SchemaStatements
      end

      if defined?(ActiveRecord::Migration::CommandRecorder)
        ActiveRecord::Migration::CommandRecorder.class_eval do
          include PowerEnum::Migration::CommandRecorder
        end
      end
    end

  end
end
