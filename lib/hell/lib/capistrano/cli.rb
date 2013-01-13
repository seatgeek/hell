require 'capistrano/cli'
require 'json'

module Capistrano
  class CLI
    module JsonTaskList

      def task_list
        config = instantiate_configuration(options)
        config.debug = options[:debug]
        config.dry_run = options[:dry_run]
        config.preserve_roles = options[:preserve_roles]
        config.logger.level = options[:verbose]

        set_pre_vars(config)
        load_recipes(config)

        config.trigger(:load)
        [config, options]

        tasks = config.task_list(:all)
        tasks.reject! {|t| HELL_BLACKLIST.include?(t.fully_qualified_name)}
        tasks = Hash[tasks.map {|task| [task.fully_qualified_name, task.to_hash]}]

        config.trigger(:exit)

        tasks
      end

      def tasks(pattern = nil, opts = {})
        @available_tasks ||= task_list
        tasks = @available_tasks.reject {|name, task| is_environment?(task)}

        if pattern.is_a?(String)
          if opts.fetch(:exact, false)
            tasks.select! {|name| name == pattern}
          else
            tasks.select! {|name| name =~ /#{pattern}/}
          end
        end

        tasks
      end

      def is_environment?(task)
        return false unless task[:options].include?(:tags)
        Array(task[:options][:tags]).include?(:hell_env)
      end
    end
  end
end
