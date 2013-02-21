require 'multi_json'
require 'pusher'

module Hell
  class TailDone < StandardError; end

  module Helpers
    def escape_to_html(data)
      {
        1 => :nothing,
        2 => :nothing,
        4 => :nothing,
        5 => :nothing,
        7 => :nothing,
        8 => :backspace,
        30 => "#303030",
        31 => "#D10915",
        32 => "#53A948",
        33 => "#CD7D3D",
        34 => "#3582E0",
        35 => :magenta,
        36 => "#30EFEF",
        37 => :white,
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
        elsif value == :backspace
          data.gsub!(/.[\b]/, '')
        else
          data.gsub!(/\e\[#{key}m/,"<span style=\"color:#{value}\">")
        end
      end
      data.gsub!(/\e\[0m/, '</span>')
      data.gsub!(/\e\[0/, '</span>')
      # data.gsub!(' ', '&nbsp;')
      data
    end

    def ansi_escape(message)
      escape_to_html(utf8_dammit(message))
    end

    def ws_message(message)
      message = {:message => ansi_escape(message)}.to_json
    end

    def stream_line(task_id, line, out, io)
      begin
        out << "data: " + ws_message(line) + "\n\n" unless out.closed?
        raise TailDone if HELL_SENTINEL_STRINGS.any? { |w| line =~ /#{w}/ }
      rescue
        Process.kill("KILL", io.pid)
      end
    end

    def push_line(task_id, line, out, io)
      begin
        Pusher[task_id].trigger('message', ws_message(line))
        raise TailDone if HELL_SENTINEL_STRINGS.any? { |w| line =~ /#{w}/ }
      rescue
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
      cmd = [
        "cd #{HELL_APP_ROOT} && echo '#{background_cmd}' >> #{HELL_LOG_PATH}/#{log_file}.log 2>&1",
        "cd #{HELL_APP_ROOT} && #{background_cmd} >> #{HELL_LOG_PATH}/#{log_file}.log 2>&1",
        "cd #{HELL_APP_ROOT} && echo 'Hellish Task Completed' >> #{HELL_LOG_PATH}/#{log_file}.log 2>&1",
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
  end
end
