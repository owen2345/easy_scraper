# frozen_string_literal: true

require_relative 'lib/scraper'
require 'sinatra'

set :port, 9494
set :bind, '0.0.0.0'

get('/') { run_scrapper }
post('/') { run_scrapper }

def run_scrapper
  allowed_params = params.slice(:session_id, :logs, :timeout, :capture_error, :cookies)
  settings = allowed_params.map{ |k, v| [k.to_sym, v] }.to_h
  inst = Scraper.new(params[:url], params[:commands], settings: settings)
  res = inst.call
  res.is_a?(File) ? render_file(res.path) : res
end

# @param path [String]
def render_file(path)
  name = File.basename(path, File.extname(path))
  file = Tempfile.new([name, File.extname(path)]) { |f| f << File.read(path) }
  File.delete(path)
  # file.rewind
  # file.close
  content_type :jpeg if file.path.to_s.end_with?('.png')
  send_file file.path
end
