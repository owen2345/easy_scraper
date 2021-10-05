# frozen_string_literal: true

require_relative 'lib/scraper'
require 'sinatra'

set :port, 9494
set :bind, '0.0.0.0'

get('/') { run_scrapper }
post('/') { run_scrapper }

def run_scrapper
  settings = params.slice(:session_id, :logs, :timeout)
  inst = Scraper.new(params[:url], params[:commands], settings: settings)
  res = inst.call
  res.is_a?(Tempfile) ? render_file(res) : res
end

# @param file [Tempfile]
def render_file(file)
  puts "rendering file: #{file.path}:::::"
  content_type :jpeg if file.path.to_s.end_with?('.png')
  send_file file.path
end
