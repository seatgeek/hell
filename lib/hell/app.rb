#!/bin/env ruby

require 'sinatra'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/streaming'
require 'sinatra/assetpack'

require 'pusher'
require 'multi_json'
require 'securerandom'

require 'hell/lib/cli'
require 'hell/lib/monkey_patch'
require 'hell/lib/helpers'

options, op = Hell::CLI.option_parser(ARGV)
op = nil

HELL_DIR              = Dir.pwd
HELL_APP_ROOT         = options[:app_root]
HELL_BLACKLIST        = ['invoke', 'shell', 'internal:ensure_env', 'internal:setup_env']
HELL_REQUIRE_ENV      = !!options[:require_env]
HELL_LOG_PATH         = options[:log_path]
HELL_BASE_PATH        = options[:base_path]
HELL_SENTINEL_STRINGS = options[:sentinel]

USE_PUSHER = !!(options[:pusher_app_id] && options[:pusher_key] && options[:pusher_secret])

PUSHER_APP_ID = options[:pusher_app_id]
PUSHER_KEY = options[:pusher_key]
PUSHER_SECRET = options[:pusher_secret]

Pusher.app_id = PUSHER_APP_ID
Pusher.key = PUSHER_KEY
Pusher.secret = PUSHER_SECRET

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

    get '/' do
      @tasks = cap.tasks.keys
      @require_env = HELL_REQUIRE_ENV
      @www_base_dir = HELL_BASE_PATH
      @environments = cap.environments

      @use_pusher = USE_PUSHER
      @pusher_app_id = PUSHER_APP_ID
      @pusher_key = PUSHER_KEY
      @pusher_secret = PUSHER_SECRET
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

    put '/tasks/:name/background' do
      tasks, original_cmd = verify_task(cap, params[:name])
      verbose = ""
      verbose = "LOGGING=debug" if params[:verbose] == "on"

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
        send_success(params[:id], "tail -f %s" % File.join(HELL_LOG_PATH, params[:id] + ".log"))
      else
        send_error(params[:id], "log file '#{params[:id]}' not found")
      end
    end

    get '/logs/:id/view' do
      log_path = File.join(HELL_LOG_PATH, params[:id] + ".log")
      logger.info log_path
      ansi_escape(File.read(log_path))
    end

    get '/tasks/:name/execute' do
      tasks, original_cmd = verify_task(cap, params[:name])
      task_id = random_id
      content_type "text/event-stream"
      if tasks.empty?
        send_error(task_id, "cap task '#{original_cmd}' not found")
      else
        send_success(task_id, "bundle exec cap -l STDOUT #{original_cmd} LOGGING=debug 2>&1", {:prepend => true})
      end
    end

    def cap
      FileUtils.chdir HELL_APP_ROOT do
        @cap ||= Capistrano::CLI.parse(["-T"])
      end
      return @cap
    end

    def send_error(task_id, message)
      stream do |out|
        out << "event: start\ndata:\n\n" unless out.closed?
        out << "data: " + ws_message("<p>#{message}</p>")  + "\n\n" unless out.closed?
        out << "event: end\ndata:\n\n" unless out.closed?
        out.close
      end
    end

    def send_success(task_id, command, opts = {})
      opts = {:prepend => false}.merge(opts)
      stream do |out|
        out << "event: start\ndata:\n\n" unless out.closed?
        out << "data: " + ws_message("<p>#{command}</p>") + "\n\n" unless out.closed? or opts[:prepend] == false
        IO.popen(command, 'rb') do |io|
          io.each {|line| stream_line(task_id, line, out, io)}
        end
        close_stream(out)
      end
    end

  end
end
