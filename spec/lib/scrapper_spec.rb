# frozen_string_literal: true

require 'spec_helper'
RSpec.describe Scraper do
  let(:uri) { 'http://sample.com' }
  let(:command) { '$(\'title\').innerText' }
  before do
    klass = Selenium::WebDriver::Chrome::Driver
    allow_any_instance_of(klass).to receive(:execute_script) { |cmd| cmd }
  end

  it 'returns the last result' do
    commands = [command, 'last_command']
    inst = described_class.new(uri, commands)
    allow(inst.send(:driver)).to receive(:execute_script) { |cmd| cmd }
    expect(inst.call).to eq(commands.last)
  end

  describe 'when navigating' do
    let(:inst) { described_class.new(uri, command) }
    let(:driver) { inst.send(:driver) }
    after { inst.call }

    it 'navigates to the defined url' do
      expect(driver.navigate).to receive(:to).with(uri)
    end
  end

  describe 'when running commands' do
    let(:inst) { described_class.new(uri, '') }
    let(:driver) { inst.send(:driver) }
    before { allow(driver).to receive(:execute_script) { |cmd| cmd } }

    describe 'when simple js command' do
      it 'performs the provided command' do
        inst.instance_variable_set(:@js_commands, [command])
        expect(driver).to receive(:execute_script).with(command)
        inst.call
      end
    end

    describe 'when complex command' do
      it 'performs :sleep command' do
        cmd = { kind: 'sleep', value: 2 }
        inst.instance_variable_set(:@js_commands, [cmd])
        expect(inst).to receive(:sleep).with(cmd[:value])
        inst.call
      end

      it 'performs :wait command' do
        cmd = { kind: 'wait', value: "return $('#my_panel .my_item')" }
        inst.instance_variable_set(:@js_commands, [cmd])
        expect(driver).to receive(:execute_script).with(cmd[:value])
        inst.call
      end

      it 'performs :screenshot command' do
        cmd = { kind: 'screenshot' }
        inst.instance_variable_set(:@js_commands, [cmd])
        allow(inst).to receive(:render_file)
        expect(driver).to receive(:save_screenshot)
        inst.call
      end

      it 'returns captured images when :screenshot command' do
        cmd = { kind: 'screenshot' }
        inst.js_commands = [cmd]
        expect_rendered_file(inst)
        inst.call
      end

      it 'performs :visit command' do
        cmd = { kind: 'visit', value: 'http://another_url.com' }
        inst.instance_variable_set(:@js_commands, [cmd])
        allow(driver.navigate).to receive(:to)
        expect(driver.navigate).to receive(:to).with(cmd[:value])
        inst.call
      end

      it 'performs :downloaded command to render last downloaded file' do
        cmd = { kind: 'downloaded' }
        pdf_link = '$(\'#my_panel a.pdf_link\')[0].click()'
        inst.instance_variable_set(:@js_commands, [pdf_link, cmd])
        inst.instance_variable_set(:@current_files, [])
        expect_rendered_file(inst)
        inst.call
      end

      describe 'when :run_if command' do
        let(:sub_command) { 'some command' }

        it 'performs command if value returns some value' do
          cmd = { kind: 'run_if', value: "return 'some value' ", commands: [sub_command] }
          inst.instance_variable_set(:@js_commands, [cmd])
          expect(driver).to receive(:execute_script).with(cmd[:value])
          inst.call
        end

        it 'does not perform command if value returns empty value' do
          cmd = { kind: 'run_if', value: '', commands: [sub_command] }
          inst.instance_variable_set(:@js_commands, [cmd])
          expect(driver).not_to receive(:execute_script).with(cmd[:value])
          inst.call
        end
      end

      describe 'when :values command' do
        it 'returns a json of multiple values' do
          sub_command1 = "return 'val1'"
          sub_command2 = "return 'val2'"
          cmd = { kind: 'values', value: [sub_command1, sub_command2] }
          inst.instance_variable_set(:@js_commands, [cmd])
          res = inst.call
          expect([sub_command1, sub_command2].to_json).to eq(res)
        end
      end

      describe 'when :until command' do
        it 'performs the command' do
          value = '$(\'.my_link\').innerText'
          commands = ['$(\'#pagination a.page\')[untilIndex].click()']
          cmd = { kind: 'until', max: 3, value: value, commands: commands }
          inst.instance_variable_set(:@js_commands, [cmd])
          allow(driver).to receive(:execute_script).with(value).and_return('')
          expect(driver).to receive(:execute_script).with(value).exactly(cmd[:max]).times
          inst.call rescue nil
        end
      end
    end
  end

  private

  def expect_rendered_file(inst)
    allow(inst).to receive(:render_file).and_return(Tempfile.new)
    expect(inst.call).to be_a(Tempfile)
  end
end
