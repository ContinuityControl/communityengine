require 'community_engine'
require 's3_cache_control'

Module.class_eval do
  def expiring_attr_reader(method_name, value)
    class_eval(<<-EOS, __FILE__, __LINE__)
      def #{method_name}
        class << self; attr_reader :#{method_name}; end
        @#{method_name} = eval(%(#{value}))
      end
    EOS
  end
end

class ActionView::Base
  def _(s)
    # just call the globalite localize method on the string
    s.localize
  end
end

module ApplicationConfiguration
  require 'ostruct'
  require 'yaml'  
  if File.exists?( File.join(Rails.root.to_s, 'config', 'application.yml') )
    file = Rails.root.join('config', 'application.yml').to_s
    users_app_config = YAML.load_file file
  end
  default_app_config = YAML.load_file(Rails.root.join('vendor', 'plugins', 'community_engine', 'config', 'application.yml').to_s)
  
  config_hash = (users_app_config||{}).reverse_merge!(default_app_config)

  unless defined?(AppConfig)
    ::AppConfig = OpenStruct.new config_hash
  else
    orig_hash   = AppConfig.marshal_dump
    merged_hash = config_hash.merge(orig_hash)
    
    AppConfig = OpenStruct.new merged_hash
  end
end


