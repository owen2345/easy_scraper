# frozen_string_literal: true

require 'selenium-webdriver'
class Scraper
  def initialize(url, js_commands)
    @url = url
    @current_files = Dir.glob('/app/*')
    print_html = 'return document.getElementsByTagName(\'html\')[0].outerHTML;'
    js_commands = js_commands.is_a?(String) ? (JSON.parse(js_commands) rescue js_commands) : js_commands
    @js_commands = Array(js_commands || print_html)
  end

  def call
    driver.navigate.to @url
    driver.manage.window.size = Selenium::WebDriver::Dimension.new(2024, 1024)
    @js_commands.map(&method(:eval_command)).last
  rescue
    driver.save_screenshot(screenshots_path("failed_#{Time.now.to_i}.png"))
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
    when 'sleep' then sleep command['value']
    when 'wait' then Selenium::WebDriver::Wait.new(timeout: 180).until { driver.find_element(:css, command['value']) }
    when 'screenshot' then capture_screenshot
    when 'visit' then driver.navigate.to(command['value'])
    when 'downloaded' then render_downloaded
    when 'until' then wait_until(command)
    end
  end

  def render_downloaded
    recent_files = Dir.glob('/app/*') - @current_files
    recent_path = recent_files.max_by { |f| File.mtime(f) }
    raise 'No download found' unless recent_path

    render_file(recent_path)
  end

  # @param command (Hash)
  #   @option value [String, Hash]
  #   @option commands [Array<String,Hash>]
  #   @option max [Integer, optional] Default 100 times
  def wait_until(command)
    (command['max'] || 100).times.each do |index|
      Array(command['commands']).each do |sub_command|
        driver.execute_script("var untilIndex = #{index};")
        eval_command(sub_command)
      end
      driver.execute_script("var untilIndex = #{index};")
      value = eval_command(command['value'])
      return value if value.to_s != ''
    end
    raise 'Timeout until'
  end

  def capture_screenshot
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
    delay = driver.execute_script('return typeof jQuery') == 'undefined'
    driver.execute_script("if(typeof jQuery == 'undefined') { #{jquery} }")
    sleep 2 if delay
  end

  def driver
    @driver ||= begin
      args = ['--headless', '--disable-gpu', '--no-sandbox', '--disable-extensions', '--disable-dev-shm-usage']
      options = Selenium::WebDriver::Chrome::Options.new(args: args, prefs: driver_prefs)
      options.add_argument('--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.82 Safari/537.36')
      caps = Selenium::WebDriver::Remote::Capabilities.new
      caps['resolution'] = '1920x1080'
      Selenium::WebDriver.for(:chrome, options: options, desired_capabilities: caps)
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
