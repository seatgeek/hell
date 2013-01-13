#!/bin/env ruby

require 'sinatra'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/streaming'
require 'sinatra/assetpack'

require 'json'
require 'securerandom'
require 'trollop'
require 'websocket'

opts = Trollop::options do
  opt :port,         "set the host",                                             :default => 4567,        :type => :integer
  opt :addr,         "set the host",                                             :default => '0.0.0.0'
  opt :server,       "specify rack server/handler",                              :default => 'thin'
  opt :x,            "turn on the mutex lock (default is false)",                :default => false
  opt :environments, "comma-separated list of environments",                     :default => 'production,staging'
  opt :app_root,     "directory from which capistrano should run",               :default => Dir.pwd
  opt :require_env,  "whether or not to require specifying an environment",      :default => true
  opt :log_path,     "path to hell logs",                                        :default => File.join(Dir.pwd, 'log')
  opt :base_dir,     "base directory to use in the web ui",                      :default => '/'
  opt :sentinel,     "sentinel string used to denote the end of a task run",     :default => 'Hellish Task Completed'
end

HELL_DIR              = Dir.pwd
HELL_APP_ROOT         = ENV.fetch('HELL_APP_ROOT', opts.app_root)
HELL_BLACKLIST        = ['invoke', 'shell', 'internal:ensure_env', 'internal:setup_env']
HELL_REQUIRE_ENV      = !!ENV.fetch('HELL_REQUIRE_ENV', opts.require_env)
HELL_LOG_PATH         = ENV.fetch('HELL_LOG_PATH', opts.log_path)
HELL_BASE_DIR         = ENV.fetch('HELL_BASE_DIR', opts.base_dir)
HELL_SENTINEL_STRINGS = ENV.fetch('HELL_SENTINEL_STRINGS', opts.sentinel).split(',')

HELL_PORT             = opts.port
HELL_ADDR             = opts.addr
HELL_SERVER           = opts.server
HELL_LOCK             = opts.x

require 'hell/lib/monkey_patch'
require 'hell/lib/helpers'

module Hell
  class App < Sinatra::Base
    helpers Sinatra::JSON
    helpers Sinatra::Streaming
    helpers Hell::Helpers

    register Sinatra::AssetPack

    set :public_folder, File.join(File.expand_path('..', __FILE__), 'public')
    set :root, HELL_DIR
    set :server, :thin
    set :static, true
    set :views, File.join(File.expand_path('..', __FILE__), 'views')

    set :port, HELL_PORT
    set :bind, HELL_ADDR
    set :server, HELL_SERVER
    set :lock, HELL_LOCK

    assets do
      css_compression :sass

      js :main, [
        '/assets/js/jquery.min.js',
        '/assets/js/underscore.min.js',
        '/assets/js/backbone.js',
        '/assets/js/backbone-localstorage.js',
        '/assets/js/bootstrap.min.js',
        '/assets/js/bootstrap.growl.js',
        '/assets/js/timeago.js',
        '/assets/js/hashchange.min.js',
        '/assets/js/hell.js',
      ]

      css :bootstrap, [
        '/assets/css/bootstrap.min.css',
        '/assets/css/bootstrap-responsive.css',
        '/assets/css/hell.css',
      ]

      prebuild true
    end

    configure :production, :development do
      enable :logging
    end

    def cap
      FileUtils.chdir HELL_APP_ROOT do
        @cap ||= Capistrano::CLI.parse(["-T"])
      end
      return @cap
    end

    get '/' do
      @tasks = cap.tasks.keys
      @require_env = HELL_REQUIRE_ENV
      @www_base_dir = HELL_BASE_DIR
      @environments = cap.environments
      erb :index
    end

    get '/tasks' do
      tasks = cap.tasks
      json tasks
    end

    get '/tasks/search/:pattern' do
      tasks = cap.tasks(params[:pattern])
      json tasks
    end

    get '/tasks/:name/exists' do
      tasks = cap.tasks(params[:name], {:exact => true})
      response = { :exists => !tasks.empty?, :task => params[:name]}
      json response
    end

    get '/tasks/:name/background' do
      tasks, original_cmd = verify_task(cap, params[:name])
      verbose = ""
      verbose = "LOGGING=debug" if params[:verbose] == true

      task_id = run_in_background!("bundle exec cap -l STDOUT %s %s" % [original_cmd, verbose]) unless tasks.empty?
      response = {}
      response[:status] = tasks.empty? ? 404 : 200,
      response[:message] = tasks.empty? ? "Task not found" : "Running task in background",
      response[:task_id] = task_id unless tasks.empty?
      json response
    end

    get '/logs/:id/tail' do
      content_type "text/event-stream"
      if valid_log params[:id]
        _stream_success("tail -f %s" % File.join(HELL_LOG_PATH, params[:id] + ".log"))
      else
        _stream_error("log file '#{params[:id]}' not found")
      end
    end

    get '/logs/:id/view' do
      log_path = File.join(HELL_LOG_PATH, params[:id] + ".log")
      logger.info log_path
      ansi_escape(File.read(log_path))
    end

    get '/tasks/:name/execute' do
      tasks, original_cmd = verify_task(cap, params[:name])
      content_type "text/event-stream"
      if tasks.empty?
        _stream_error("cap task '#{original_cmd}' not found")
      else
        _stream_success("bundle exec cap -l STDOUT #{original_cmd} LOGGING=debug 2>&1", {:prepend => true})
      end
    end

    def _stream_error(message)
      stream do |out|
        out << "event: start\ndata:\n\n" unless out.closed?
        out << "data: " + ws_message("<p>#{message}</p>") unless out.closed?
        out << "event: end\ndata:\n\n" unless out.closed?
        out.close
      end
    end

    def _stream_success(command, opts = {})
      opts = {:prepend => false}.merge(opts)
      stream do |out|
        out << "event: start\ndata:\n\n" unless out.closed?
        out << "data: " + ws_message("<p>#{command}</p>") unless out.closed? or opts[:prepend] == false
        IO.popen(command, 'rb') do |io|
          io.each do |line|
            process_line(line, out, io)
          end
        end
        close_stream(out)
      end
    end
  end
end
