#
# Cookbook Name:: nova
# Recipe:: api-ec2
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
  include ::Opscode::OpenSSL::Password
end

include_recipe "nova::nova-common"

platform_options = node["nova"]["platform"]

directory "/var/lock/nova" do
  owner node["nova"]["user"]
  group node["nova"]["group"]
  mode  00700

  action :create
end

package "python-keystone" do
  action :upgrade
end

platform_options["api_ec2_packages"].each do |pkg|
  package pkg do
    options platform_options["package_overrides"]

    action :upgrade
  end
end

service "nova-api-ec2" do
  service_name platform_options["api_ec2_service"]
  supports :status => true, :restart => true
  subscribes :restart, resources(:template => "/etc/nova/nova.conf"), :delayed

  action :enable
end

# The node that runs the nova-setup recipe first
# will create a secure service password
nova_setup_role = node["nova"]["nova_setup_chef_role"]
nova_setup_info = config_by_role nova_setup_role, "nova"

identity_admin_endpoint = endpoint "identity-admin"
identity_endpoint = endpoint "identity-api"
keystone_service_role = node["nova"]["keystone_service_chef_role"]
keystone = get_settings_by_role keystone_service_role, "keystone"

ec2_admin_endpoint = endpoint "compute-ec2-admin"
ec2_public_endpoint = endpoint "compute-ec2-api"

# Register Service Tenant
keystone_register "Register Service Tenant" do
  auth_host identity_admin_endpoint.host
  auth_port identity_admin_endpoint.port.to_s
  auth_protocol identity_admin_endpoint.scheme
  api_ver identity_admin_endpoint.path
  auth_token keystone["admin_token"]
  tenant_name nova_setup_info["service_tenant_name"]
  tenant_description "Service Tenant"

  action :create_tenant
end

# Register Service User
keystone_register "Register Service User" do
  auth_host identity_admin_endpoint.host
  auth_port identity_admin_endpoint.port.to_s
  auth_protocol identity_admin_endpoint.scheme
  api_ver identity_admin_endpoint.path
  auth_token keystone["admin_token"]
  tenant_name nova_setup_info["service_tenant_name"]
  user_name nova_setup_info["service_user"]
  user_pass nova_setup_info["service_pass"]

  action :create_user
end

# Grant Admin role to Service User for Service Tenant
keystone_register "Grant 'admin' Role to Service User for Service Tenant" do
  auth_host identity_admin_endpoint.host
  auth_port identity_admin_endpoint.port.to_s
  auth_protocol identity_admin_endpoint.scheme
  api_ver identity_admin_endpoint.path
  auth_token keystone["admin_token"]
  tenant_name nova_setup_info["service_tenant_name"]
  user_name nova_setup_info["service_user"]
  role_name nova_setup_info["service_role"]

  action :grant_role
end

# Register EC2 Service
keystone_register "Register EC2 Service" do
  auth_host identity_admin_endpoint.host
  auth_port identity_admin_endpoint.port.to_s
  auth_protocol identity_admin_endpoint.scheme
  api_ver identity_admin_endpoint.path
  auth_token keystone["admin_token"]
  service_name "ec2"
  service_type "ec2"
  service_description "EC2 Compatibility Layer"

  action :create_service
end

# Register EC2 Endpoint
keystone_register "Register Compute Endpoint" do
  auth_host identity_admin_endpoint.host
  auth_port identity_admin_endpoint.port.to_s
  auth_protocol identity_admin_endpoint.scheme
  api_ver identity_admin_endpoint.path
  auth_token keystone["admin_token"]
  service_type "ec2"
  endpoint_region node["nova"]["region"]
  endpoint_adminurl ::URI.decode ec2_admin_endpoint.to_s
  endpoint_internalurl ::URI.decode ec2_public_endpoint.to_s
  endpoint_publicurl ::URI.decode ec2_public_endpoint.to_s

  action :create_endpoint
end

template "/etc/nova/api-paste.ini" do
  source "api-paste.ini.erb"
  owner  "root"
  group  "root"
  mode   00644
  variables(
    "identity_admin_endpoint" => identity_admin_endpoint,
    "nova_setup_info" => nova_setup_info
  )

  notifies :restart, resources(:service => "nova-api-ec2"), :delayed
end
