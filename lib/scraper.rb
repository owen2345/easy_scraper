# frozen_string_literal: true

require 'selenium-webdriver'
class Scraper
  def initialize(url, js_commands, settings: {})
    settings = { auto_download: true, session_id: nil, timeout: 180 }.merge(settings)
    @auto_download = settings[:auto_download].to_s == 'true'
    @url = url
    @current_files = Dir.glob('/app/*')
    @js_commands = parsed_commands(js_commands)
    @timeout = settings[:timeout]
    @session_id = settings[:session_id]
  end

  def self.drivers
    @drivers = {}
  end

  def call
    driver.navigate.to @url
    @js_commands.map(&method(:eval_command)).last
  rescue
    path = screenshots_path("failed_#{Time.now.to_i}.png")
    puts "Due to failure, screenshot was captured at: #{path}"
    driver.save_screenshot(path)
    raise
  end

  private

  # @param command(String, Hash)
  #   @option kind (screenshot|sleep|wait)
  #   @option value (String)
  def eval_command(command)
    include_jquery
    puts "Running.......... #{command}:::#{command.class}"
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
    when 'wait' then until_timeout { driver.execute_script(command['value']) }
    when 'screenshot' then run_screenshot_cmd
    when 'visit' then driver.navigate.to(command['value'])
    when 'downloaded' then run_downloaded_cmd
    when 'until' then run_until_cmd(command)
    when 'values' then run_values_cmd(command['value'])
    when 'run_if' then run_if_cmd(command)
    end
  end

  # @param commands [Array<command>]
  def run_values_cmd(commands)
    values = commands.map do |command|
      eval_command(command)
    end
    values.map { |value| value.is_a?(Tempfile) ? Base64.encode64(value.read) : value }.to_json
  end

  def run_if_cmd(command)
    result = driver.execute_script(command['value']).to_s
    return unless result.empty?

    run_values_cmd(command['commands'])
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

    Array(command['commands']).each do |sub_command|
      driver.execute_script("var untilIndex = #{index};")
      eval_command(sub_command)
    end
    nil
  end

  def until_timeout(&block)
    Selenium::WebDriver::Wait.new(timeout: @timeout).until do
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
    File.delete(path)
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
    drivers[@session_id] = new_driver if @session_id && !drivers[@session_id]
    @driver = drivers[@session_id] || new_driver
  end


  def new_driver
    args = ['--headless', '--disable-gpu', '--no-sandbox', '--disable-extensions', '--disable-dev-shm-usage']
    options = Selenium::WebDriver::Chrome::Options.new(args: args, prefs: driver_prefs)
    options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36')
    caps = Selenium::WebDriver::Remote::Capabilities.new
    caps['resolution'] = '1920x1080'
    driver = Selenium::WebDriver.for(:chrome, options: options, desired_capabilities: caps)
    driver.manage.window.size = Selenium::WebDriver::Dimension.new(2024, 1024)
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
        'always_open_pdf_externally' => @auto_download
      }
    }
  end

  def parsed_commands(commands)
    print_html = 'return document.getElementsByTagName(\'html\')[0].outerHTML;'
    commands = commands.is_a?(String) ? (JSON.parse(commands) rescue commands) : commands
    Array(commands || print_html)
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
end
