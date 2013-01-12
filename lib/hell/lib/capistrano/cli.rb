require 'capistrano/cli'
require 'json'

module Capistrano
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

        tasks.reject! {|t| HELL_BLACKLIST.include?(t.fully_qualified_name)}
        tasks.reject! {|t| HELL_ENVIRONMENTS.include?(t.fully_qualified_name)}
        tasks.reject! {|t| t.service.include?(opts.fetch(:service))} if opts.fetch(:service, false)

        tasks = Hash[tasks.map {|task| [task.fully_qualified_name, task.to_hash]}]
        task_after(config)

        tasks
      end
    end
  end
end
