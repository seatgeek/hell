require 'multi_json'
require 'pusher'

module Hell
  class TailDone < StandardError; end

  module Helpers

    def escape_to_html(data)
      {
        1  => {:color => :none,     :class => "bold",           :type => :special},
        2  => {:color => :none,     :class => "low-intensity",  :type => :special},
        3  => {:color => :none,     :class => "italic",         :type => :special},
        4  => {:color => :none,     :class => "underline",      :type => :special},
        5  => {:color => :none,     :class => "blink-slow",     :type => :special},
        5  => {:color => :none,     :class => "blink-rapid",    :type => :special},
        7  => {:color => :none,     :class => "reverse",        :type => :special},
        8  => {:color => :none,     :class => "conceal",        :type => :special},
        9  => {:color => :none,     :class => "crossed-out",    :type => :special},
        30 => {:color => "000000",  :class => "color-black",    :type => :color},
        31 => {:color => "7F0000",  :class => "color-red",      :type => :color},
        32 => {:color => "007F05",  :class => "color-green",    :type => :color},
        33 => {:color => "807F00",  :class => "color-yellow",   :type => :color},
        34 => {:color => "0D0080",  :class => "color-blue",     :type => :color},
        35 => {:color => "800080",  :class => "color-magenta",  :type => :color},
        36 => {:color => "00807F",  :class => "color-cyan",     :type => :color},
        37 => {:color => "C0C0C0",  :class => "color-white",    :type => :color},
        40 => :nothing,
        41 => :nothing,
        43 => :nothing,
        44 => :nothing,
        45 => :nothing,
        46 => :nothing,
        47 => :nothing,
      }.each do |key, value|
        if value == :nothing
          data.gsub!(/\e\[#{key}m/,"<span>")
        elsif value.is_a? Hash
          if value[:class] == 'conceal'
            data.gsub!(/.[\b]/, '')
          else
            data.gsub!(/\e\[#{key}m/, "<span class=\"#{value[:class]}\">")
          end
        end
      end
      data.gsub!(/\e\[0m/, '</span>')
      data.gsub!(/\e\[0/, '</span>')
      # data.gsub!(' ', '&nbsp;')
      data
    end

    def ansi_escape(message)
      Hell::Helpers::escape_to_html(Hell::Helpers::utf8_dammit(message))
    end

    def ws_message(message)
      {:message => Hell::Helpers::ansi_escape(message)}
    end

    def stream_line(task_id, line, out, io)
      begin
        out << "data: " + ws_message(line) + "\n\n" unless out.closed?
        raise TailDone if HELL_SENTINEL_STRINGS.any? { |w| line =~ /#{w}/ }
      rescue
        Process.kill("KILL", io.pid)
      end
    end

    def push_line(task_id, line, io)
      begin
        Pusher[task_id].trigger('message', MultiJson.dump(Hell::Helpers::ws_message(line)))
        raise TailDone if HELL_SENTINEL_STRINGS.any? { |w| line =~ /#{w}/ }
      rescue StandardError => e
        Process.kill("KILL", io.pid)
      end
    end

    def close_stream(out)
      out << "event: end\ndata:\n\n" unless out.closed?
      out.close
    end

    def random_id
      Time.now.to_i.to_s + '.' + SecureRandom.hex(2)
    end

    def run_in_background!(background_cmd)
      log_file = random_id
      task_end = HELL_SENTINEL_STRINGS.first
      cmd = [
        "cd #{HELL_APP_ROOT} && echo '#{background_cmd}' >> #{HELL_LOG_PATH}/#{log_file}.log 2>&1",
        "cd #{HELL_APP_ROOT} && #{background_cmd} >> #{HELL_LOG_PATH}/#{log_file}.log 2>&1",
        "cd #{HELL_APP_ROOT} && echo '#{task_end}' >> #{HELL_LOG_PATH}/#{log_file}.log 2>&1",
      ].join(" ; ")
      system("sh -c \"#{cmd}\" &")

      # Wait up to three seconds in case of server load
      i = 0
      while i < 3
        i += 1
        break if File.exists?(File.join(HELL_LOG_PATH, log_file + ".log"))
        sleep 1
      end

      log_file
    end

    def tail_in_background!(task_id)
      cmd = "cd #{HELL_LOG_PATH} && HELL_TASK_ID='#{task_id}' HELL_SENTINEL_STRINGS='#{HELL_SENTINEL_STRINGS.join(',')}' bundle exec hell-pusher"
      system("sh -c \"#{cmd}\" &")
    end

    def verify_task(cap, name)
      original_cmd = name.gsub('+', ' ').gsub!(/\s+/, ' ').strip
      cmd = original_cmd.split(' ')
      cmd.shift if cap.environments.include?(cmd.first)
      cmd = cmd.join(' ')

      tasks = cap.tasks(cmd, {:exact => true})
      return tasks, original_cmd
    end

    def valid_log(id)
      File.exists?(File.join(HELL_LOG_PATH, id + ".log"))
    end

    def utf8_dammit(s)
      # Converting ASCII-8BIT to UTF-8 based domain-specific guesses
      if s.is_a? String
        begin
          # Try it as UTF-8 directly
          cleaned = s.dup.force_encoding('UTF-8')
          unless cleaned.valid_encoding?
            # Some of it might be old Windows code page
            cleaned = s.encode( 'UTF-8', 'Windows-1252' )
          end
          s = cleaned
        rescue EncodingError
          # Force it to UTF-8, throwing out invalid bits
          s.encode!('UTF-8', :invalid => :replace, :undef => :replace)
        end
        s
      end
    end

    def json_encode(data)
      MultiJson.dump(data)
    end

    def pusher_error(task_id, message)
      Pusher[task_id].trigger('start', MultiJson.dump(Hell::Helpers::ws_message("<p>start</p>")))
      Pusher[task_id].trigger('message', MultiJson.dump(Hell::Helpers::ws_message("<p>#{message}</p>")))
      Pusher[task_id].trigger('end', MultiJson.dump(Hell::Helpers::ws_message("<p>end</p>")))
    end

    def pusher_success(task_id, command, opts = {})
      out = nil
      opts = {:prepend => false}.merge(opts)
      Pusher[task_id].trigger('start', MultiJson.dump(Hell::Helpers::ws_message("<p>start</p>")))
      Pusher[task_id].trigger('message', MultiJson.dump(Hell::Helpers::ws_message("<p>#{command}</p>"))) unless opts[:prepend] == false
      IO.popen(command, 'rb') do |io|
        io.each do |line|
          Hell::Helpers::push_line(task_id, line, io)
        end
      end
      Pusher[task_id].trigger('end', MultiJson.dump(Hell::Helpers::ws_message("<p>end</p>")))
    end

    module_function :pusher_error
    module_function :pusher_success
    module_function :push_line
    module_function :valid_log
    module_function :ws_message
    module_function :utf8_dammit
    module_function :ansi_escape
    module_function :escape_to_html

  end
end
