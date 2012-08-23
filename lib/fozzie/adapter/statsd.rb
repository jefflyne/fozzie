require 'socket'

module Fozzie
  module Adapter

    class Statsd

      RESERVED_CHARS_REGEX       = /[\:\|\@\s]/
      RESERVED_CHARS_REPLACEMENT = '_'
      DELIMETER                  = '.'
      TYPES                      = { :gauge => 'g', :count => 'c', :timing => 'ms' }

      # Send the statistic to the server
      #
      # Creates the Statsd key from the given values, and sends to socket (depending on sample rate)
      #
      def register(stat, delta, type, sample_rate)
        bucket = format_bucket(stat)
        value  = format_value(delta, type, sample_rate)

        packet = [bucket, value].join(':')

        sampled(sample_rate) { send_to_socket(packet) }
      end

      def format_bucket(stat)
        bucket = [stat].flatten.compact.collect(&:to_s).join(DELIMETER).downcase
        bucket = bucket.gsub('::', DELIMETER).gsub(RESERVED_CHARS_REGEX, RESERVED_CHARS_REPLACEMENT)
        bucket = [Fozzie.c.data_prefix, bucket].compact.join(DELIMETER)

        bucket
      end

      def format_value(val, type, sample_rate)
        converted_type = TYPES[type.to_sym]
        converted_type ||= TYPES[:gauge]

        value = [val, converted_type].join('|')
        value << '@%s' % sample_rate.to_s if sample_rate < 1

        value
      end

      # If the statistic is sampled, generate a condition to check if it's good to send
      def sampled(sample_rate)
        yield unless sample_rate < 1 and rand > sample_rate
      end

      # Send data to the server via the socket
      def send_to_socket(message)
        begin
          Fozzie.logger.debug {"Statsd: #{message}"} if Fozzie.logger
          Timeout.timeout(Fozzie.c.timeout) {
            res = socket.send(message, 0, Fozzie.c.host, Fozzie.c.port)
            Fozzie.logger.debug {"Statsd sent: #{res}"} if Fozzie.logger
            (res.to_i == message.length)
          }
        rescue => exc
          Fozzie.logger.debug {"Statsd Failure: #{exc.message}\n#{exc.backtrace}"} if Fozzie.logger
          false
        end
      end

      # The Socket we want to use to send data
      def socket
        @socket ||= ::UDPSocket.new
      end

    end

  end
end