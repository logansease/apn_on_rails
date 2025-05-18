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
      #   ENV['APN_PASSPHRASE'] = ''
      #   ENV['APN_PORT'] = '443'
      #   ENV['APN_CERT'] = File.join(rails_root, 'config', 'apple_push_notification_development.pem')) # Development
      #   ENV['APN_CERT'] = File.join(rails_root, 'config', 'apple_push_notification_production.pem')) # Production
      #   ENV['APN_TOPIC'] = 'com.example.app' # Bundle ID
      #   ENV['APN_PRIORITY'] = '10' # Default priority
      #   ENV['APN_AUTH_TOKEN'] = 'your_auth_token' # For token-based auth
      def open_for_delivery(options = {}, &block)
        open(options, &block)
      end
      
      # Yields up an SSL socket to receive feedback from.
      # The connections are close automatically.
      # Configuration parameters are:
      # 
      #   ENV['APN_FEEDBACK_PASSPHRASE'] = ''
      #   ENV['APN_FEEDBACK_PORT'] = '2196'
      #   ENV['APN_FEEDBACK_CERT'] = File.join(rails_root, 'config', 'apple_push_notification_development.pem')) # Development
      #   ENV['APN_FEEDBACK_CERT'] = File.join(rails_root, 'config', 'apple_push_notification_production.pem')) # Production
      def open_for_feedback(options = {}, &block)
        options = {
          :passphrase => ENV['APN_FEEDBACK_PASSPHRASE'],
          :host => 'feedback.sandbox.push.apple.com', # Default to sandbox
          :port => 2196
        }.merge(options)
        open(options, &block)
      end
      
      private
      def open(options = {}, &block) # :nodoc:
        options = {
          :port => 443,
          :use_ssl => true
        }.merge(options)

        require 'net/http'
        require 'net/https'
        
        uri = URI("https://#{options[:host]}:#{options[:port]}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        # Only set up certificate if no auth token is provided
        if options[:cert] && !options[:auth_token]
          begin
            http.cert = OpenSSL::X509::Certificate.new(options[:cert])
            http.key = OpenSSL::PKey::RSA.new(options[:cert], options[:passphrase])
          rescue OpenSSL::X509::CertificateError, OpenSSL::PKey::RSAError => e
            Rails.logger.error "Failed to load APN certificate: #{e.message}"
            # raise APN::Errors::CertificateError.new("Failed to load APN certificate: #{e.message}")
          end
        end
        
        http.start do |http|
          yield http, nil if block_given?
        end
      end
      
    end
    
  end # Connection
end # APN