#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2010 Opscode, Inc.
# License:: Apache License, Version 2.0
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

require 'chef/knife'
require 'json'

class Chef
  class Knife
    class Ec2ServerCreate < Knife

      banner "Sub-Command: ec2 server create [RUN LIST...] (options)"

      option :flavor,
        :short => "-f FLAVOR",
        :long => "--flavor FLAVOR",
        :description => "The flavor of server (m1.small, m1.medium, etc)",
        :default => "m1.small"

      option :image,
        :short => "-i IMAGE",
        :long => "--image IMAGE",
        :description => "The AMI for the server",
        :default => "ami-17f51c7e"

      option :security_groups,
        :short => "-G X,Y,Z",
        :long => "--groups X,Y,Z",
        :description => "The security groups for this server",
        :default => ["default"],
        :proc => Proc.new { |groups| groups.split(',') }

      option :availability_zone,
        :short => "-Z ZONE",
        :long => "--availability-zone ZONE",
        :description => "The Availability Zone",
        :default => "us-east-1b"

      option :ssh_key_name,
        :short => "-S KEY",
        :long => "--ssh-key KEY",
        :description => "The SSH root key",
        :proc => Proc.new { |key| Chef::Config[:knife][:aws_ssh_key_id] = key }

      option :aws_access_key_id,
        :short => "-A ID",
        :long => "--aws-access-key-id KEY",
        :description => "Your AWS Access Key ID",
        :proc => Proc.new { |key| Chef::Config[:knife][:aws_access_key_id] = key } 

      option :aws_secret_access_key,
        :short => "-K SECRET",
        :long => "--aws-secret-access-key SECRET",
        :description => "Your AWS API Secret Access Key",
        :proc => Proc.new { |key| Chef::Config[:knife][:aws_secret_access_key] = key } 

      def h
        @highline ||= HighLine.new
      end

      def run 
        require 'fog'
        require 'highline'
        require 'net/ssh/multi'
        require 'readline'

        $stdout.sync = true

        connection = Fog::AWS::EC2.new(
          :aws_access_key_id => Chef::Config[:knife][:aws_access_key_id],
          :aws_secret_access_key => Chef::Config[:knife][:aws_secret_access_key]
        )

        server = connection.servers.create(
          :image_id => config[:image],
          :groups => config[:security_groups],
          :flavor_id => config[:flavor],
          :key_name => Chef::Config[:knife][:aws_ssh_key_id],
          :user_data => {
            "chef_server" => Chef::Config[:chef_server_url],
            "validation_client_name" => Chef::Config[:validation_client_name],
            "validation_key" => IO.read(Chef::Config[:validation_key]),
            "attributes" => { "run_list" => @name_args } 
          }.to_json,
          :availability_zone => config[:availability_zone]
        )

        puts "#{h.color("Instance ID", :cyan)}: #{server.id}"
        puts "#{h.color("Flavor", :cyan)}: #{server.flavor_id}"
        puts "#{h.color("Image", :cyan)}: #{server.image_id}"
        puts "#{h.color("Availability Zone", :cyan)}: #{server.availability_zone}"
        puts "#{h.color("Security Groups", :cyan)}: #{server.groups.join(", ")}"
        puts "#{h.color("SSH Key", :cyan)}: #{server.key_name}"
     
        print "\n#{h.color("Waiting for server", :magenta)}"

        # wait for it to be ready to do stuff
        server.wait_for { print "."; ready? }

        print "\n\n"

        puts "#{h.color("Public DNS Name", :cyan)}: #{server.dns_name}"
        puts "#{h.color("Public IP Address", :cyan)}: #{server.ip_address}"
        puts "#{h.color("Private DNS Name", :cyan)}: #{server.private_dns_name}"
        puts "#{h.color("Private IP Address", :cyan)}: #{server.private_ip_address}"

      end
    end
  end
end



