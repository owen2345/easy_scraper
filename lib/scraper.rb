# frozen_string_literal: true

require 'selenium-webdriver'
require_relative './ext/array'
class Scraper
  def initialize(url, js_commands, settings: {})
    @settings = { session_id: nil, timeout: 180, logs: true }.merge(settings)
    @url = url
    @current_files = Dir.glob('/app/*')
    @js_commands = parsed_commands(js_commands)
    @session_id = settings[:session_id]
  end

  def self.drivers
    @drivers ||= {}
  end

  def call
    log "Visiting to #{@url}"
    driver.navigate.to @url
    @js_commands.map(&method(:eval_command)).last
  rescue
    capture_failed_screenshot
    raise
  ensure # auto remove downloaded files
    (Dir.glob('/app/*') - @current_files).each { |f_path| File.delete(f_path) }
  end

  private

  def capture_failed_screenshot
    path = screenshots_path("failed_#{Time.now.to_i}.png")
    log "Due to failure, screenshot was captured at: #{path}"
    driver.save_screenshot(path)
  end

  # @param command(String, Hash)
  #   @option kind (screenshot|sleep|wait)
  #   @option value (String)
  def eval_command(command)
    include_jquery
    log "Running.......... #{command}:::#{command.class}"
    if command.is_a?(Hash)
      eval_complex_command(command.transform_keys(&:to_s))
    else
      driver.execute_script(command)
    end
  end

  # @param command (Hash)
  def eval_complex_command(command)
    case command['kind']
    when 'sleep' then sleep command['value'].to_f
    when 'wait' then run_wait_cmd(command)
    when 'screenshot' then run_screenshot_cmd
    when 'visit' then driver.navigate.to(command['value'])
    when 'downloaded' then run_downloaded_cmd
    when 'until' then run_until_cmd(command)
    when 'values' then run_values_cmd(command['value'])
    when 'run_if' then run_if_cmd(command)
    end
  end

  def run_wait_cmd(command)
    until_timeout do
      res = driver.execute_script(command['value'])
      print_command_result(command['value'], res)
      res
    end
  end

  # @param commands [Array<command>]
  def run_values_cmd(commands)
    values = commands.map do |sub_commands|
      Array.wrap(sub_commands).map { |command| eval_command(command) }.last
    end
    values.map { |value| value.is_a?(Tempfile) ? Base64.encode64(File.read(value.path)) : value }.to_json
  end

  def run_if_cmd(command)
    result = driver.execute_script(command['value']).to_s
    print_command_result(command['value'], result)
    run_values_cmd(command['commands']) unless result.empty?
  end

  def run_downloaded_cmd
    recent_files = Dir.glob('/app/*') - @current_files
    recent_path = recent_files.max_by { |f| File.mtime(f) }
    raise 'No download found' unless recent_path

    render_file(recent_path)
  end

  # @param command (Hash)
  #   @option value [String, Hash]
  #   @option commands [Array<String,Hash>]
  #   @option max [Integer, optional] Default 100 times
  def run_until_cmd(command)
    (command['max'] || 100).to_i.times.each do |index|
      res = check_until_value(command, index)
      return res if res
    end
    raise 'Timeout until'
  end

  def check_until_value(command, index)
    driver.execute_script("var untilIndex = #{index};")
    value = eval_command(command['value'])
    return value if value.to_s != ''

    Array.wrap(command['commands']).each do |sub_command|
      driver.execute_script("var untilIndex = #{index};")
      eval_command(sub_command)
    end
    nil
  end

  def until_timeout(&block)
    Selenium::WebDriver::Wait.new(timeout: @settings[:timeout]).until do
      block.call
    end
  end

  def run_screenshot_cmd
    filename = screenshots_path("picture#{Time.now.to_i}.png")
    driver.save_screenshot(filename)
    render_file(filename)
  end

  def render_file(path)
    name = File.basename(path, File.extname(path))
    file = Tempfile.new([name, File.extname(path)])
    file.write(File.read(path))
    # File.delete(path)
    file.rewind
    file.close
    file
  end

  def include_jquery
    jquery = "let script = document.createElement('script');
    document.head.appendChild(script);
    script.type = 'text/javascript';
    script.src = 'https://ajax.googleapis.com/ajax/libs/jquery/3.1.0/jquery.min.js';
    await script.onload;"
    driver.execute_script("if(typeof jQuery == 'undefined') { #{jquery} }")
    until_timeout { driver.execute_script("return typeof jQuery == 'undefined' ? null : true") }
  end

  def driver
    return @driver if @driver

    drivers = self.class.drivers # TODO: add session expiration
    self.class.drivers[@session_id] = new_driver if @session_id && !drivers[@session_id]
    @driver = self.class.drivers[@session_id] || new_driver
  end


  def new_driver
    args = ['--headless', '--disable-gpu', '--no-sandbox', '--disable-extensions', '--disable-dev-shm-usage']
    options = Selenium::WebDriver::Chrome::Options.new(args: args, prefs: driver_prefs)
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36')
    caps = Selenium::WebDriver::Remote::Capabilities.new
    caps['resolution'] = '1920x1080'
    driver = Selenium::WebDriver.for(:chrome, options: options, desired_capabilities: caps)
    driver.manage.window.size = Selenium::WebDriver::Dimension.new(2024, 1024)
    driver.manage.timeouts.script_timeout = @settings[:timeout]
    driver
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

  def parsed_commands(commands)
    print_html = 'return document.getElementsByTagName(\'html\')[0].outerHTML;'
    commands = commands.is_a?(String) ? (JSON.parse(commands) rescue commands) : commands
    res = Array.wrap(commands)
    res.empty? ? [print_html] : res
  end

  def screenshots_path(filename = nil)
    path = '/app/screenshots'
    FileUtils.mkdir_p(path) unless Dir.exist?(path)
    path = "#{path}/#{filename}" if filename
    path
  end

  def downloads_path
    '/app/downloads/'
  end

  def print_command_result(command, result)
    result = result.is_a?(Tempfile) ? result.path : result
    log "====== result for: #{command}: #{result}"
  end

  def log(msg)
    puts msg if @settings[:logs]
  end
end
