require 'capistrano/task_definition'

module Capistrano
  class TaskDefinition
    attr_reader :service

    def service
      @service ||= Array(@options.delete(:service))
    end

    def to_hash
      {
        :name => name,
        :fully_qualified_name => fully_qualified_name,
        :description => description == brief_description ? false : description,
        :brief_description => brief_description,
      }
    end
  end
end
