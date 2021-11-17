# frozen_string_literal: true

require 'spec_helper'
RSpec.describe DriversManager do
  let(:session_id) { '111' }
  let(:url) { 'http://google.com' }
  before { described_class.instance_variable_set(:@driver_wrappers, {}) }

  describe 'when session id is provided' do
    let(:inst) { described_class.new(session_id, url: url, timeout: 10, process_id: 1) }

    it 'returns a new driver wrapper if no available found' do
      expect(inst).to receive(:new_driver).and_call_original
      inst.driver_wrapper
    end

    it 'saves the new wrapper into global wrappers list' do
      wrapper = inst.driver_wrapper
      wrappers = described_class.driver_wrappers[session_id]
      expect(wrappers).to include(wrapper)
    end

    describe 'when there is an available wrapper' do
      let!(:inst0) { described_class.new(session_id, url: url, timeout: 10, process_id: 2) }
      let!(:wrapper0) { inst0.driver_wrapper }
      before { inst0.quit_driver }

      it 'returns an available driver wrapper for session id if exist' do
        expect(inst.driver_wrapper).to eq(wrapper0)
      end

      it 'reserves wrapper for current process' do
        wrapper = inst.driver_wrapper
        expect(wrapper.in_use).to be_truthy
      end
    end

    describe 'when finishing wrapper' do

      it 'releases wrapper to be used by others' do
        wrapper = inst.driver_wrapper
        expect(wrapper).to receive(:in_use=).with(false)
        inst.quit_driver
      end

      describe 'when there are more wrappers than allowed' do
        before { stub_const("#{described_class}::QTY_OPEN_SESSIONS", 0) }

        it 'quits the driver' do
          wrapper = inst.driver_wrapper
          expect(wrapper.driver).to receive(:quit)
          inst.quit_driver
        end

        it 'removes the wrapper from the global list' do
          wrapper = inst.driver_wrapper
          expect(wrapper.driver).to receive(:quit)
          inst.quit_driver
          expect(described_class.driver_wrappers).not_to include(wrapper)
        end
      end
    end
  end

  describe 'when no session id' do
    let(:inst) { described_class.new(nil, url: url, timeout: 10, process_id: 1) }

    it 'returns a new driver wrapper' do
      expect(inst).to receive(:new_driver).and_call_original
      inst.driver_wrapper
    end

    it 'quits the driver when finishing wrapper' do
      wrapper = inst.driver_wrapper
      expect(wrapper.driver).to receive(:quit)
      inst.quit_driver
    end
  end
end
