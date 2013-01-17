#!/bin/env ruby

require 'sinatra'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/streaming'
require 'sinatra/assetpack'

require 'json'
require 'securerandom'
require 'websocket'

# TODO: Refactor
options = {}
options[:app_root] = ENV.fetch('HELL_APP_ROOT', Dir.pwd)
options[:base_path] = ENV.fetch('HELL_BASE_PATH', '/')
options[:log_path] = ENV.fetch('HELL_LOG_PATH', File.join(Dir.pwd, 'log'))
options[:require_env] = !!ENV.fetch('HELL_REQUIRE_ENV', true)
options[:sentinel] = ENV.fetch('HELL_SENTINEL_STRINGS', 'Hellish Task Completed').split(',')

op = OptionParser.new do |opts|
  opts.on('-a', '--app-root APP_ROOT', 'directory from which capistrano should run') do |opt|
    options[:app_root] = opt if opt
  end

  opts.on('-b', '--base-path BASE_PATH', 'base directory path to use in the web ui') do |opt|
    options[:base_path] = opt if opt
  end

  opts.on('-L', '--log-path LOG_PATH', 'directory path to hell logs') do |opt|
    options[:log_path] = opt if opt
  end

  opts.on('-R', '--require-env REQUIRE_ENV', 'whether or not to require specifying an environment') do |opt|
    options[:require_env] = !!opt if opt
  end

  opts.on('-S', '--sentinel', 'sentinel string used to denote the end of a task run') do |opt|
    options[:sentinel] = opt.split(',') if opt
  end

  opts.parse! ARGV
end

HELL_DIR              = Dir.pwd
HELL_APP_ROOT         = options[:app_root]
HELL_BLACKLIST        = ['invoke', 'shell', 'internal:ensure_env', 'internal:setup_env']
HELL_REQUIRE_ENV      = !!options[:require_env]
HELL_LOG_PATH         = options[:log_path]
HELL_BASE_PATH        = options[:base_path]
HELL_SENTINEL_STRINGS = options[:sentinel]

op = nil

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

    assets do
      css_compression :sass

      js :jquery, [
        '/assets/js/jquery.js',
      ]

      js :main, [
        '/assets/js/backbone-localstorage.js',
        '/assets/js/bootstrap.growl.js',
        '/assets/js/timeago.js',
        '/assets/js/hashchange.js',
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
      @www_base_dir = HELL_BASE_PATH
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
