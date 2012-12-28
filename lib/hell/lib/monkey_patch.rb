require 'json'
require 'capistrano'
require 'capistrano/cli'
require 'capistrano/cli/help'
require 'capistrano/task_definition'

module Capistrano
  class TaskDefinition
    def to_hash
      {
        :name => name,
        :fully_qualified_name => fully_qualified_name,
        :description => description == brief_description ? false : description,
        :brief_description => brief_description,
      }
    end
  end

  class CLI
    module JsonTaskList
      def task_before
        config = instantiate_configuration(options)
        config.debug = options[:debug]
        config.dry_run = options[:dry_run]
        config.preserve_roles = options[:preserve_roles]
        config.logger.level = options[:verbose]

        set_pre_vars(config)
        load_recipes(config)

        config.trigger(:load)
        [config, options]
      end

      def task_after(config)
        config.trigger(:exit)
        config
      end

      def task_index(pattern = nil, opts = {})
        config, options = task_before

        tasks = config.task_list(:all)
        if opts.fetch(:exact, false) && pattern.is_a?(String)
          tasks.select! {|t| t.fully_qualified_name == pattern}
        elsif pattern.is_a?(String)
          tasks.select! {|t| t.fully_qualified_name =~ /#{pattern}/}
        end

        tasks.reject! {|t| BLACKLIST.include?(t.fully_qualified_name)}
        tasks.reject! {|t| ENVIRONMENTS.include?(t.fully_qualified_name)}
        tasks.reject! {|t| t.service.include?(opts.fetch(:service))} if opts.fetch(:service, false)

        tasks = Hash[tasks.map {|task| [task.fully_qualified_name, task.to_hash]}]
        task_after(config)

        tasks
      end
    end
  end
end

module Capistrano
  class CLI
    include JsonTaskList
    include Help
  end
end

module Capistrano
  class TaskDefinition
    attr_reader :service

    def service
      @service ||= Array(@options.delete(:service))
    end

  end
end
