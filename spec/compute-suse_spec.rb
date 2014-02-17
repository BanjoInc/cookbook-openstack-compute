# encoding: UTF-8

require_relative 'spec_helper'

describe 'openstack-compute::compute' do
  before { compute_stubs }
  describe 'suse' do
    before do
      @chef_run = ::ChefSpec::Runner.new ::SUSE_OPTS do |n|
        # TODO: Remove work around once https://github.com/customink/fauxhai/pull/77 merges
        n.set['cpu']['total'] = 1
      end
      @chef_run.converge 'openstack-compute::compute'
    end

    it 'installs nfs client packages' do
      expect(@chef_run).to upgrade_package 'nfs-utils'
      expect(@chef_run).not_to upgrade_package 'nfs-utils-lib'
    end
  end
end
