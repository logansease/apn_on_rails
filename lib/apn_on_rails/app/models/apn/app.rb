class APN::App < APN::Base

  has_many :groups, :class_name => 'APN::Group', :dependent => :destroy
  has_many :devices, :class_name => 'APN::Device', :dependent => :destroy
  has_many :notifications, :through => :devices, :dependent => :destroy
  has_many :unsent_notifications, :through => :devices
  has_many :group_notifications, :through => :groups
  has_many :unsent_group_notifications, :through => :groups

  def cert
    if(self.override_prod)
      apn_dev_cert
    else
      (Rails.env == 'production' || Rails.env == 'staging' ? apn_prod_cert : apn_dev_cert)
    end
  end

  def host
    host = configatron.apn.host

    if host
      return host
    end

    dev_host = "api.sandbox.push.apple.com"
    prod_host = "api.push.apple.com"

    if(self.override_prod)
      dev_host
    else
      (Rails.env == 'production' || Rails.env == 'staging' ? prod_host : dev_host)
    end
  end

  def apns_topic
    ENV['APNS_TOPIC'] || configatron.apn.topic
  end

  def apns_priority
    ENV['APNS_PRIORITY'] || configatron.apn.priority || 10
  end

  def auth_token
    ENV['APNS_AUTH_TOKEN'] || configatron.apn.auth_token
  end

  def use_token_auth?
    !auth_token.nil?
  end

  # Opens a connection to the Apple APN server and attempts to batch deliver
  # an Array of group notifications.
  #
  #
  # As each APN::GroupNotification is sent the <tt>sent_at</tt> column will be timestamped,
  # so as to not be sent again.
  #
  def send_notifications
    if self.cert.nil?
     # raise APN::Errors::MissingCertificateError.new
     # return
    end
    APN::App.send_notifications_for_cert(self.cert, self.id, self.host)
  end

  def self.send_notifications
    apps = APN::App.all
    apps.each do |app|
      app.send_notifications
    end

  end

  def self.send_notifications_for_cert(the_cert, app_id, host)
    begin
      app = APN::App.find(app_id)
      connection_options = { :host => host }
      
      # Only include cert if no auth token is present
      if !app.use_token_auth?
        connection_options[:cert] = the_cert
      end
      
      APN::Connection.open_for_delivery(connection_options) do |http|
        notifications = APN::Notification.joins(:device).where(:apn_devices => {:app_id => app_id}).where(:sent_at => nil)
        notification_ids = notifications.pluck(:id)
        notifications.update_all :sent_at => Time.now

        APN::Notification.where(:id => notification_ids).find_each do |noty|
          path = "/3/device/#{noty.device.token.delete(' ')}"
          headers = {
            'apns-topic' => noty.app.apns_topic,
            'apns-priority' => noty.app.apns_priority.to_s
          }
          
          if noty.app.use_token_auth?
            headers['authorization'] = "bearer #{noty.app.auth_token}"
          end
          
          request = Net::HTTP::Post.new(path, headers)
          request.body = noty.to_apple_json
          
          response = http.request(request)
          
          if response.code != '200'
            Rails.logger.error "APN Error: #{response.code} - #{response.body}"
          end
        end
      end
    rescue Exception => e
      log_connection_exception(e)
    end
  end

  def send_group_notifications
    if self.cert.nil? && !self.use_token_auth?
      raise APN::Errors::MissingCertificateError.new
      return
    end
    unless self.unsent_group_notifications.nil? || self.unsent_group_notifications.empty?
      connection_options = { :host => host }
      
      # Only include cert if no auth token is present
      if !self.use_token_auth?
        connection_options[:cert] = self.cert
      end
      
      APN::Connection.open_for_delivery(connection_options) do |http|
        unsent_group_notifications.each do |gnoty|
          gnoty.devices.find_each do |device|
            path = "/3/device/#{device.token.delete(' ')}"
            headers = {
              'apns-topic' => self.apns_topic,
              'apns-priority' => self.apns_priority.to_s
            }
            
            if self.use_token_auth?
              headers['authorization'] = "bearer #{self.auth_token}"
            end
            
            request = Net::HTTP::Post.new(path, headers)
            request.body = gnoty.to_apple_json
            
            response = http.request(request)
            
            if response.code != '200'
              Rails.logger.error "APN Error: #{response.code} - #{response.body}"
            end
          end
          gnoty.sent_at = Time.now
          gnoty.save
        end
      end
    end
  end

  def send_group_notification(gnoty)
    if self.cert.nil? && !self.use_token_auth?
      raise APN::Errors::MissingCertificateError.new
      return
    end
    unless gnoty.nil?
      connection_options = { :host => host }
      
      # Only include cert if no auth token is present
      if !self.use_token_auth?
        connection_options[:cert] = self.cert
      end
      
      APN::Connection.open_for_delivery(connection_options) do |http|
        gnoty.devices.find_each do |device|
          path = "/3/device/#{device.token.delete(' ')}"
          headers = {
            'apns-topic' => self.apns_topic,
            'apns-priority' => self.apns_priority.to_s
          }
          
          if self.use_token_auth?
            headers['authorization'] = "bearer #{self.auth_token}"
          end
          
          request = Net::HTTP::Post.new(path, headers)
          request.body = gnoty.to_apple_json
          
          response = http.request(request)
          
          if response.code != '200'
            Rails.logger.error "APN Error: #{response.code} - #{response.body}"
          end
        end
        gnoty.sent_at = Time.now
        gnoty.save
      end
    end
  end

  def self.send_group_notifications
    apps = APN::App.all
    apps.each do |app|
      app.send_group_notifications
    end
  end

  # Retrieves a list of APN::Device instnces from Apple using
  # the <tt>devices</tt> method. It then checks to see if the
  # <tt>last_registered_at</tt> date of each APN::Device is
  # before the date that Apple says the device is no longer
  # accepting notifications then the device is deleted. Otherwise
  # it is assumed that the application has been re-installed
  # and is available for notifications.
  #
  # This can be run from the following Rake task:
  #   $ rake apn:feedback:process
  def process_devices
    if self.cert.nil?
      raise APN::Errors::MissingCertificateError.new
      return
    end
    APN::App.process_devices_for_cert(self.cert)
  end # process_devices

  def self.process_devices
    apps = APN::App.all
    apps.each do |app|
      app.process_devices
    end

  end

  def self.process_devices_for_cert(the_cert)
    puts "in APN::App.process_devices_for_cert"
    APN::Feedback.devices(the_cert).each do |device|
      if device.last_registered_at < device.feedback_at
        puts "device #{device.id} -> #{device.last_registered_at} < #{device.feedback_at}"
        device.destroy
      else
        puts "device #{device.id} -> #{device.last_registered_at} not < #{device.feedback_at}"
      end
    end
  end

  protected

  def self.log_connection_exception(ex)
    STDERR.puts ex.message
    raise ex
  end

end
