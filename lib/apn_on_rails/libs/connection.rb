module APN
  module Connection
    
    class << self
      
      # Yields up an HTTP/2 connection to write notifications to.
      # The connections are close automatically.
      # 
      #  Example:
      #   APN::Configuration.open_for_delivery do |conn|
      #     conn.write('my cool notification')
      #   end
      # 
      # Configuration parameters are:
      # 
      #   configatron.apn.passphrase = ''
      #   configatron.apn.port = 443
      #   configatron.apn.host = 'api.sandbox.push.apple.com' # Development
      #   configatron.apn.host = 'api.push.apple.com' # Production
      #   configatron.apn.cert = File.join(rails_root, 'config', 'apple_push_notification_development.pem')) # Development
      #   configatron.apn.cert = File.join(rails_root, 'config', 'apple_push_notification_production.pem')) # Production
      #   configatron.apn.topic = 'com.example.app' # Bundle ID
      #   configatron.apn.priority = 10 # Default priority
      #   configatron.apn.auth_token = 'your_auth_token' # For token-based auth
      def open_for_delivery(options = {}, &block)
        open(options, &block)
      end
      
      # Yields up an SSL socket to receive feedback from.
      # The connections are close automatically.
      # Configuration parameters are:
      # 
      #   configatron.apn.feedback.passphrase = ''
      #   configatron.apn.feedback.port = 2196
      #   configatron.apn.feedback.host = 'feedback.sandbox.push.apple.com' # Development
      #   configatron.apn.feedback.host = 'feedback.push.apple.com' # Production
      #   configatron.apn.feedback.cert = File.join(rails_root, 'config', 'apple_push_notification_development.pem')) # Development
      #   configatron.apn.feedback.cert = File.join(rails_root, 'config', 'apple_push_notification_production.pem')) # Production
      def open_for_feedback(options = {}, &block)
        options = {:cert => configatron.apn.feedback.cert,
                   :passphrase => configatron.apn.feedback.passphrase,
                   :host => configatron.apn.feedback.host,
                   :port => configatron.apn.feedback.port}.merge(options)
        open(options, &block)
      end
      
      private
      def open(options = {}, &block) # :nodoc:
        options = {
          :cert => configatron.apn.cert,
          :passphrase => configatron.apn.passphrase,
          :port => 443,
          :use_ssl => true
        }.merge(options)

        require 'net/http'
        require 'net/https'
        
        uri = URI("https://#{options[:host]}:#{options[:port]}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        # Only set up certificate if no auth token is provided
        if options[:cert]
          http.cert = OpenSSL::X509::Certificate.new(options[:cert])
          http.key = OpenSSL::PKey::RSA.new(options[:cert], options[:passphrase])
        end
        
        http.start do |http|
          yield http, nil if block_given?
        end
      end
      
    end
    
  end # Connection
end # APN