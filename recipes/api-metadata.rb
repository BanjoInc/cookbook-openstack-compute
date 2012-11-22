#
# Cookbook Name:: nova
# Recipe:: api-metadata
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Chef::Recipe
  include ::Openstack
end

include_recipe "nova::nova-common"

platform_options = node["nova"]["platform"]

directory "/var/lock/nova" do
    owner "nova"
    group "nova"
    mode  00755

    action :create
end

package "python-keystone" do
  action :upgrade
end

platform_options["nova_api_metadata_packages"].each do |pkg|
  package pkg do
    options platform_options["package_overrides"]

    action :upgrade
  end
end

service "nova-api-metadata" do
  service_name platform_options["nova_api_metadata_service"]
  supports :status => true, :restart => true
  subscribes :restart, resources(:template => "/etc/nova/nova.conf"), :delayed

  action :enable
end

identity_admin_endpoint = endpoint "identity-admin"
identity_endpoint = endpoint "identity-api"
keystone_service_role = node["nova"]["keystone_service_chef_role"]
keystone = get_settings_by_role keystone_service_role, "keystone"

template "/etc/nova/api-paste.ini" do
  source "api-paste.ini.erb"
  owner  "root"
  group  "root"
  mode   00644
  variables(
    :keystone_api_ipaddress => identity_admin_endpoint["host"],
    :service_port => identity_endpoint["port"],
    :admin_port => identity_admin_endpoint["port"],
    :admin_token => keystone["admin_token"]
  )

  notifies :restart, resources(:service => "nova-api-metadata"), :delayed
end
