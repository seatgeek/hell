require 'capistrano/configuration/loading'

module Capistrano
  class Configuration
    module Loading
      alias_method :original_initialize_with_loading, :initialize_with_loading
      def initialize_with_loading(*args) #:nodoc:
        orig = original_initialize_with_loading(*args)
        @load_paths.unshift(HELL_APP_ROOT)
        return orig
      end
    end
  end
end
