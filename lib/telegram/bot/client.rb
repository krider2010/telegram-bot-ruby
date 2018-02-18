module Telegram
  module Bot
    class Client
      attr_reader :api, :options
      attr_accessor :logger

      def self.run(*args, &block)
        new(*args).run(&block)
      end

      def initialize(token, h = {})
        @options = default_options.merge(h)
        @api = Api.new(token)
        @logger = options.delete(:logger)
      end

      def run
        yield self
      end

      def listen(&block)
        logger.info('Starting bot')
        catch(:stop) {
          loop { fetch_updates(&block) }
        }
      end

      # This can also be written in any calling code (the throw does not have to appear
      # within the static scope of the catch), but is included here for completeness
      def stop
        throw :stop
      end

      # Listen for a given period of time (in minutes)
      def listen_for(minutes = 15, &block)
        counter == 15 * 60
        interval = 5 # Check every 5 seconds
        interval_timer = 1 # must start at 1
        now = Time.now
        while Time.now - now < counter
          if interval_timer % interval == 0
            fetch_updates(&block)
          end
          interval_timer = interval_timer + 1
        end
      end

      def fetch_updates
        response = api.getUpdates(options)
        return unless response['ok']

        response['result'].each do |data|
          update = Types::Update.new(data)
          @options[:offset] = update.update_id.next
          message = update.current_message
          log_incoming_message(message)
          yield message
        end
      rescue Faraday::Error::TimeoutError
        retry
      end

      private

      def default_options
        { offset: 0, timeout: 20, logger: NullLogger.new }
      end

      def log_incoming_message(message)
        uid = message.from ? message.from.id : nil
        logger.info(
          format('Incoming message: text="%s" uid=%s', message, uid)
        )
      end
    end
  end
end
