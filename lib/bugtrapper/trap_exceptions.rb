require 'httparty'
module BugTrapper
  BUGTRAPPER_API_URI = 'http://localhost:3002/dev/record-exceptions'

  class TrapExceptions
    def initialize(app, ops = {})
      @app = app
      @app_id = ops[:app_id]
    end

    def call(env)
      begin
        @app.call(env)
      rescue StandardError => e
        @exception = e
        capture_exceptions(env)
        raise e
      end
    end

    private

    def capture_exceptions(env)
      body = {
        message: @exception.message,
        error_details: {
          backtrace: @exception.backtrace[0..5].join("\n"),
          environment: env.first(30).to_h
        },
        application_id: @app_id
      }.to_json
      
      HTTParty.post(
        BUGTRAPPER_API_URI,
        headers: {
          'Content-Type' => 'application/json'
        },
        body: body
      )
    end

    def source_location
      lines[start_line..end_line].join
    end

    def source
      @exception.backtrace.first.split(":")
    end

    def file_location
      source[0]
    end

    def start_line
      [source[1].to_i - 5, 0].max
    end

    def end
      source[1].to_i + 5
    end

    def lines
      File.readLines(file_location)
    end
  end
end