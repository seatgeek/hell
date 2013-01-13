require 'capistrano/task_definition'

module Capistrano
  class TaskDefinition

    def to_hash
      # Roles should always be a hash, to ease developer frustration
      @options[:roles] = Array(@options[:roles])
      {
        :name => name,
        :fully_qualified_name => fully_qualified_name,
        :description => description == brief_description ? false : description,
        :brief_description => brief_description,
        :options => @options,
      }
    end
  end
end
