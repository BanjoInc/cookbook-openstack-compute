# encoding: UTF-8

require_relative 'spec_helper'

describe 'openstack-compute::api-metadata' do
  before { compute_stubs }
  describe 'redhat' do
    before do
      @chef_run = ::ChefSpec::Runner.new ::REDHAT_OPTS do |n|
        # TODO: Remove work around once https://github.com/customink/fauxhai/pull/77 merges
        n.set['cpu']['total'] = 1
      end
      @chef_run.converge 'openstack-compute::api-metadata'
    end

    it 'installs metadata api packages' do
      expect(@chef_run).to upgrade_package 'openstack-nova-api'
    end

    it 'starts metadata api on boot' do
      expect(@chef_run).to enable_service 'openstack-nova-api'
    end
  end
end
