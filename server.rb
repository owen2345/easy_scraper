# frozen_string_literal: true

require_relative 'lib/scraper'
require 'sinatra'

set :port, 9494
set :bind, '0.0.0.0'

get('/') { run_scrapper }
post('/') { run_scrapper }

def run_scrapper
  allowed_params = params.slice(:session_id, :logs, :timeout, :capture_error, :cookies, :driver_settings)
  settings = allowed_params.map{ |k, v| [k.to_sym, v] }.to_h
  inst = Scraper.new(params[:url], params[:commands], settings: settings)
  res = inst.call
  [File, Tempfile].include?(res.class) ? render_file(res) : res
end

def render_file(res_file)
  path = res_file.path
  file = res_file.is_a?(Tempfile) ? res_file : Scraper.make_tempfile(path)
  content_type :jpeg if file.path.to_s.end_with?('.png')
  send_file file.path
end
