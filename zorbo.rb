require 'rubygems'
require 'open-uri'
require 'hpricot'
require 'net/smtp'
require 'mailfactory'

class ZorboConfig
  attr_accessor :log_file, :alert_temp, :delay, :alert_delay,
                :vent_url, :tower_url, :smtp_address, :to_address, :from_address

  def initialize
    @log_file = "path\\to\\zorbo.log"

    @alert_temp  = 84   # degrees f
    @delay       = 1800 # seconds between temp check
    @alert_delay = 1800 # seconds between temp check when in alert state

    # Environment Monitor URLs
    @vent_url  = "http://155.97.98.52/index.html?eR"
    @tower_url = "http://155.97.98.52/index.html?em"

    @smtp_address = "my.smtp.address"
    @to_address   = "to@you.com"    
    @from_address = "from@zorbo.com"
  end
end

def send_mail(subject, body)
  to_address   = CONFIG.to_address
  from_address = CONFIG.from_address
  
  mail         = MailFactory.new
  mail.to      = to_address
  mail.from    = from_address
  mail.subject = subject
  mail.text    = body

  Net::SMTP.start(CONFIG.smtp_address, 25, from_address) { |smtp|
    smtp.send_message(mail.to_s, from_address, to_address)
  }
end

def write_to_log(log_message)
  time    = Time.now.strftime("%Y-%m-%d %H:%M:%S")
  env_log = File.new(CONFIG.log_file, "a")
    env_log.puts "#{time} #{log_message}"
  env_log.close
end

def check_temp
  tower_string = Hpricot(open(CONFIG.tower_url)).search("body").inner_html
  tower_temp   = tower_string.scan(/(..\..)/)[0][0]

  vent_string  = Hpricot(open(CONFIG.vent_url)).search("body").inner_html
  vent_temp    = vent_string.scan(/(..\..)/)[0][0]

  log_message  = "Tower: #{tower_temp} Vent: #{vent_temp}"
  write_to_log(log_message)

  return tower_temp, vent_temp
end

#####  BEGIN #####
CONFIG = ZorboConfig.new
alert_state = :no_alert

while true
  tower_temp, vent_temp = check_temp

  if tower_temp.to_f >= CONFIG.alert_temp
    alert_state = :alert

    body = "Hello Citizen,\n\nExcess heat has been located in Sector 5.\n\nTower: #{tower_temp}\nVent: #{vent_temp}\n\nYou may now panic.\n\nWith Love,\nZorbo the Automated Thermometer"
    subject = "Temperature Alert!"
    send_mail(subject, body)

    log_message = "ALERT Tower: #{tower_temp} Vent: #{vent_temp}"
    write_to_log(log_message)

    sleep CONFIG.alert_delay
    next
  end

  if alert_state == :alert
    alert_state = :no_alert

    body = "Hello Citizen,\n\nSuccess! Excess heat in Sector 5 has been vented.\n\nTower: #{tower_temp}\nVent: #{vent_temp}\n\nYour exemplary performance has been noted.\n\nWith Love,\nZorbo the Automated Thermometer"
    subject = "All Clear!"
    send_mail(subject, body)

    log_message = "ALERT CLEARED Tower: #{tower_temp} Vent: #{vent_temp}"
  end

  write_to_log(log_message)
  sleep CONFIG.delay
end
