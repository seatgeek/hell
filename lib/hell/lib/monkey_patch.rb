require 'hell/lib/capistrano/configuration'
require 'hell/lib/capistrano/cli'
require 'hell/lib/capistrano/task_definition'

require 'capistrano/cli'
require 'capistrano/cli/help'

module Capistrano
  class CLI
    include JsonTaskList
    include Help
  end
end
