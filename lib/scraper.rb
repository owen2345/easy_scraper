# frozen_string_literal: true

require 'forwardable'
require 'selenium-webdriver'
require_relative './ext/array'
require_relative './drivers_manager'
class Scraper
  extend Forwardable
  def_delegators :@driver_manager, :driver_wrapper, :driver
  attr_accessor :settings, :js_commands, :driver_manager

  def initialize(url, js_commands, settings: {})
    @settings = { session_id: nil, timeout: 180, logs: true, capture_error: false, cookies: nil }.merge(settings)
    @url = url
    @current_files = Dir.glob("#{downloads_folder}/*")
    @js_commands = parsed_commands(js_commands)
    @process_id = "#{Time.now.to_i}-#{rand(1000)}"
    manager_settings = {
      timeout: @settings[:timeout].to_i, process_id: @process_id, cookies: @settings[:cookies], url: url
    }
    @driver_manager = DriversManager.new(settings[:session_id], manager_settings)
  end

  def call
    driver_wrapper
    log "Navigating to (session: #{@session_id}) #{@url} with #{@js_commands.inspect}"
    driver.navigate.to @url
    @js_commands.map(&method(:eval_command)).last
  rescue => e
    retry_call?(e) ? retry : capture_failed_screenshot(e)
    raise
  ensure # auto remove downloaded files
    (Dir.glob("#{downloads_folder}/*.pdf") - @current_files).each { |f_path| File.delete(f_path) }
    driver_manager.quit_driver
  end

  def self.make_tempfile(path)
    name = File.basename(path, File.extname(path))
    file = Tempfile.new([name, File.extname(path)])
    File.write(file.path, File.read(path))
    File.delete(path)
    file.rewind
    file.close
    file
  end

  private

  def capture_failed_screenshot(error)
    path = screenshots_path('failed.png')
    html_path = screenshots_path('failed.html')
    log("Failed: #{error.class.name}##{error.message} (screenshot at: #{path})", force: true)
    log(error.backtrace, force: true)
    File.open(html_path, 'a+') { |f| f << (driver.execute_script('return document.body.innerHTML;') rescue '') }
    driver.save_screenshot(path) rescue nil
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
      auto_retry { driver.execute_script(command) }
    end
  end

  # @param command (Hash)
  def eval_complex_command(command)
    case command['kind']
    when 'sleep' then sleep command['value'].to_f
    when 'wait' then run_wait_cmd(command)
    when 'screenshot' then run_screenshot_cmd(command)
    when 'visit' then auto_retry(Net::ReadTimeout) { driver.navigate.to(command['value']) }
    when 'downloaded' then run_downloaded_cmd
    when 'until' then run_until_cmd(command)
    when 'values' then run_values_cmd(command['value'])
    when 'run_if' then run_if_cmd(command)
    when 'jquery' then include_jquery(force: true)
    end
  end

  #   @option timeout [Integer, optional] Timeout time before raising error
  #   @option rescue [String, optional] Command to be executed when time out
  def run_wait_cmd(command)
    until_timeout(command['timeout']) do
      res = driver.execute_script(command['value'])
      print_command_result(command['value'], res)
      res
    end
  rescue
    command['rescue'] ? eval_command(command['rescue']) : raise
  end

  # @param commands [Array<command>]
  def run_values_cmd(commands)
    values = commands.map do |sub_commands|
      value = Array.wrap(sub_commands).map { |command| eval_command(command) }.last
      value.respond_to?(:path) ? Base64.encode64(File.read(value.path)) : value
    end
    values.to_json
  end

  def run_if_cmd(command)
    result = driver.execute_script(command['value']).to_s
    print_command_result(command['value'], result)
    run_values_cmd(command['commands']) unless result.empty?
  end

  # @return [Tempfile, Nil]
  def run_downloaded_cmd
    recent_files = Dir.glob("#{downloads_folder}/*") - @current_files
    recent_path = recent_files.max_by { |f| File.mtime(f) }
    recent_path ? self.class.make_tempfile(recent_path) : nil
  end

  # @param command (Hash)
  #   @option value [String, Hash]
  #   @option commands [Array<String,Hash>]
  #   @option max [Integer, optional] Default 100 times
  #   @option rescue [String, optional] Command to be executed when time out
  def run_until_cmd(command)
    (command['max'] || 100).to_i.times.each do |index|
      res = check_until_value(command, index)
      return res if res
    end
    command['rescue'] ? eval_command(command['rescue']) : raise('Timeout until')
  end

  def check_until_value(command, index)
    driver.execute_script("var untilIndex = #{index};")
    value = eval_command(command['value'])
    return value if value.to_s != ''

    Array.wrap(command['commands']).each do |sub_command|
      driver.execute_script("window['untilIndex'] = #{index};")
      log("defined untilIndex = #{index} for => #{sub_command}")
      eval_command(sub_command)
    end
    nil
  end

  def until_timeout(timeout = nil, &block)
    Selenium::WebDriver::Wait.new(timeout: (timeout || @settings[:timeout]).to_i).until do
      block.call
    end
  end

  # @param command (Hash<kind: String, value: String, html: Boolean>)
  # @return [File]
  def run_screenshot_cmd(command)
    name = command['value'] || 'picture'
    filename = screenshots_path("#{name}.png")
    filename_html = screenshots_path("#{name}.html")
    driver.save_screenshot(filename)
    html_code = driver.execute_script('return document.body.innerHTML;')
    File.open(filename_html, 'a+') { |f| f << html_code } if command['html']
    log("captured imaged was saved at: #{filename}")
    File.open(filename)
  end

  def include_jquery(force: false)
    jquery = "let script = document.createElement('script');
    document.head.appendChild(script);
    script.type = 'text/javascript';
    script.src = 'https://ajax.googleapis.com/ajax/libs/jquery/3.1.0/jquery.min.js';
    await script.onload;"
    if force
      driver.execute_script(jquery)
      sleep 1
    else
      driver.execute_script("if(typeof jQuery == 'undefined') { #{jquery} }")
    end
  end

  def parsed_commands(commands)
    print_html = 'return document.body.innerHTML;'
    commands = commands.is_a?(String) ? (JSON.parse(commands) rescue commands) : commands
    res = Array.wrap(commands)
    res.empty? ? [print_html] : res
  end

  def screenshots_path(filename = nil)
    path = '/app/screenshots'
    FileUtils.mkdir_p(path) unless Dir.exist?(path)
    path = "#{path}/#{@process_id}-#{filename}" if filename
    path
  end

  def print_command_result(command, result)
    result = result.respond_to?(:path) ? result.path : result
    log "====== result for: #{command} ==> #{result}"
  end

  def auto_retry(klass_name = nil, times: 2, &block)
    block.call
  rescue => e # rubocop:disable Style/RescueStandardError
    do_raise = -> { (@retry_times = 0) && raise }
    @retry_times = (@retry_times || 0) + 1
    unexpected_error = klass_name && !Array(klass_name).include?(e.class)
    do_raise.call if unexpected_error || @retry_times > times

    sleep 1
    log("Failed with: #{e.message}. Retrying...", force: true)
    retry
  end

  def log(msg, force: false)
    puts "#{@process_id}: #{msg}" if @settings[:logs] || force
  end

  def downloads_folder
    path = '/root/Downloads/'
    Dir.mkdir(path) unless Dir.exist?(path)
    path
  end

  def retry_call?(error)
    @qty_call_retry = (@qty_call_retry || 0) + 1
    return unless error.message.include?('chrome not reachable')
    return if @qty_call_retry > DriversManager::QTY_OPEN_SESSIONS

    log("Retrying chrome error (#{@qty_call_retry}): #{error.class.name}-#{error.message}")
    driver_manager.close_wrapper
    true
  end
end
