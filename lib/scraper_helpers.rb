# frozen_string_literal: true

module ScraperHelpers
  def driver_prefs # rubocop:disable Metrics/MethodLength
    {
      download: {
        prompt_for_download: false,
        directory_upgrade: true,
        extensions_to_open: '',
        default_directory: downloads_folder # not working with current version of chrome
      },
      plugins: {
        'always_open_pdf_externally' => true
      }
    }
  end

  def downloads_folder
    path = '/root/Downloads/'
    Dir.mkdir(path) unless Dir.exist?(path)
    path
  end

  # @param cookies (Hash<domain: String, url: String, values: Hash<key => value>>)
  def add_cookies(driver, cookies, default_url)
    driver.get(cookies['url'] || default_url)
    cookies['values'].each do |k, v|
      driver.manage.add_cookie(name: k, value: v, domain: cookies['domain'], path: '/', secure: false)
    end
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

  def print_command_result(command, result)
    result = result.respond_to?(:path) ? result.path : result
    log "====== result for: #{command} ==> #{result}"
  end
end
