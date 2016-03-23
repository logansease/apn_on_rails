class APN::PullNotification < APN::Base
  belongs_to :app, :class_name => 'APN::App'
  
  validates_presence_of :app_id

  def self.latest_since(app_id, since_date=nil)
    if since_date
      res = where("app_id = ? AND created_at > ? AND launch_notification = ?", app_id, since_date, false).order("created_at DESC").first
    else

      res = where("app_id = ? AND launch_notification = ?", app_id, true).order("created_at DESC").first

      res = where("app_id = ? AND launch_notification = ?", app_id, false).order("created_at DESC").first unless res
    end
    res
  end
  
  def self.all_since(app_id, since_date=nil)
    if since_date
      res = where("app_id = ? AND created_at > ? AND launch_notification = ?", app_id, since_date, false).order("created_at DESC")
    else 
      res = where("app_id = ? AND launch_notification = ?", app_id, false).order("created_at DESC")
    end
    res
  end
end