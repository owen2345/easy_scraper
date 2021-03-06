# frozen_string_literal: true

class DriversManager
  QTY_OPEN_SESSIONS = 5
  attr_reader :session_id

  DriverWrapper = Struct.new(:driver, :in_use, :process_id, keyword_init: true)
  # @param session_id (String, Nil)
  # @param cookies (Nil, Hash<domain: String, url?: String, values: Hash<name:value>>)
  def initialize(session_id, url:, timeout:, process_id:, cookies: nil)
    @session_id = session_id
    @timeout = timeout
    @process_id = process_id
    @cookies = cookies
    @url = (cookies && cookies['url']) || url
    driver_wrappers[session_id] ||= [] if session_id
  end

  # @return [DriverWrapper]
  def driver_wrapper
    @driver_wrapper ||= session_id ? available_driver : new_driver_manager
  end

  def close_wrapper
    quit_driver(force: true)
    @driver_wrapper = nil
  end

  def driver
    driver_wrapper.driver
  end

  def quit_driver(force: false)
    driver_wrapper.in_use = false
    end_driver = -> { driver.quit rescue nil }
    return end_driver.call unless session_id
    return if !force && driver_wrappers[@session_id].size <= QTY_OPEN_SESSIONS

    end_driver.call
    driver_wrappers[@session_id] = driver_wrappers[@session_id] - [driver_wrapper]
  end

  # @return [Hash<session_id:Array<DriverWrapper>>]
  def self.driver_wrappers
    @driver_wrappers ||= {}
  end

  def driver_wrappers
    self.class.driver_wrappers
  end

  private

  def available_driver
    res = driver_wrappers[session_id].find { |driver_w| !driver_w.in_use }
    unless res
      res = new_driver_manager
      driver_wrappers[session_id] << res
    end
    res.process_id = @process_id
    res.in_use = true
    res
  end

  def new_driver_manager
    @new_driver_manager ||= begin
      puts "--- opening new browser: #{@url}"
      DriverWrapper.new(driver: new_driver, in_use: true, process_id: @process_id)
    end
  end

  def new_driver
    args = [
      '--disable-gpu', '--no-sandbox', '--window-size=1280,1696', '--disable-extensions',
      '--user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Safari/537.36"'
    ]
    options = Selenium::WebDriver::Chrome::Options.new(args: args, prefs: driver_prefs)
    options.add_argument('start-maximized')
    caps = Selenium::WebDriver::Remote::Capabilities.new
    driver = Selenium::WebDriver.for(:chrome, options: options, desired_capabilities: caps)
    driver.manage.timeouts.script_timeout = @timeout
    add_cookies(driver) if @cookies
    driver
  end

  def add_cookies(driver)
    driver.get(@url)
    @cookies['values'].each do |k, v|
      driver.manage.add_cookie(name: k, value: v, domain: @cookies['domain'], path: '/', secure: false)
    end
  end

  def driver_prefs # rubocop:disable Metrics/MethodLength
    {
      download: {
        prompt_for_download: false,
        directory_upgrade: true,
        extensions_to_open: '',
        default_directory: downloads_path # not working with current version of chrome
      },
      plugins: {
        'always_open_pdf_externally' => true
      }
    }
  end

  def downloads_path
    '/app/downloads/'
  end
end
