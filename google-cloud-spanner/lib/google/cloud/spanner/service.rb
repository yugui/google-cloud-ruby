# Copyright 2016 Google Inc. All rights reserved.
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


require "google/cloud/errors"
require "google/cloud/spanner/credentials"
require "google/cloud/spanner/version"
require "google/cloud/spanner/v1"
require "google/cloud/spanner/admin/instance/v1"
require "google/cloud/spanner/admin/database/v1"
require "google/cloud/spanner/convert"

module Google
  module Cloud
    module Spanner
      ##
      # @private Represents the gRPC Spanner service, including all the API
      # methods.
      class Service
        attr_accessor :project, :credentials, :host, :timeout, :client_config

        ##
        # Creates a new Service instance.
        def initialize project, credentials, host: nil, timeout: nil,
                       client_config: nil
          @project = project
          @credentials = credentials
          @host = host || V1::SpannerClient::SERVICE_ADDRESS
          @timeout = timeout
          @client_config = client_config || {}
        end

        def channel
          require "grpc"
          GRPC::Core::Channel.new host, nil, chan_creds
        end

        def chan_creds
          return credentials if insecure?
          require "grpc"
          GRPC::Core::ChannelCredentials.new.compose \
            GRPC::Core::CallCredentials.new credentials.client.updater_proc
        end

        def service
          return mocked_service if mocked_service
          @service ||= \
            V1::SpannerClient.new(
              service_path: host,
              channel: channel,
              timeout: timeout,
              client_config: client_config,
              lib_name: "gccl",
              lib_version: Google::Cloud::Spanner::VERSION)
        end
        attr_accessor :mocked_service

        def instances
          return mocked_instances if mocked_instances
          @instances ||= \
            Admin::Instance::V1::InstanceAdminClient.new(
              service_path: host,
              channel: channel,
              timeout: timeout,
              client_config: client_config,
              lib_name: "gccl",
              lib_version: Google::Cloud::Spanner::VERSION)
        end
        attr_accessor :mocked_instances

        def databases
          return mocked_databases if mocked_databases
          @databases ||= \
            Admin::Database::V1::DatabaseAdminClient.new(
              service_path: host,
              channel: channel,
              timeout: timeout,
              client_config: client_config,
              lib_name: "gccl",
              lib_version: Google::Cloud::Spanner::VERSION)
        end
        attr_accessor :mocked_databases

        def insecure?
          credentials == :this_channel_is_insecure
        end

        def list_instances token: nil, max: nil
          call_options = nil
          call_options = Google::Gax::CallOptions.new page_token: token if token

          execute do
            paged_enum = instances.list_instances project_path,
                                                  page_size: max,
                                                  options: call_options

            paged_enum.page.response
          end
        end

        def get_instance name
          execute do
            instances.get_instance instance_path(name)
          end
        end

        def create_instance instance_id, name: nil, config: nil, nodes: nil,
                            labels: nil
          labels = Hash[labels.map { |k, v| [String(k), String(v)] }] if labels

          create_obj = Google::Spanner::Admin::Instance::V1::Instance.new({
            display_name: name, config: instance_config_path(config),
            node_count: nodes, labels: labels
          }.delete_if { |_, v| v.nil? })

          execute do
            instances.create_instance project_path, instance_id, create_obj
          end
        end

        def update_instance instance_obj
          mask = Google::Protobuf::FieldMask.new(
            paths: %w(display_name node_count labels))

          execute do
            instances.update_instance instance_obj, mask
          end
        end

        def delete_instance name
          execute do
            instances.delete_instance instance_path(name)
          end
        end

        def get_instance_policy name
          execute do
            instances.get_iam_policy instance_path(name)
          end
        end

        def set_instance_policy name, new_policy
          execute do
            instances.set_iam_policy instance_path(name), new_policy
          end
        end

        def test_instance_permissions name, permissions
          execute do
            instances.test_iam_permissions instance_path(name), permissions
          end
        end

        def list_instance_configs token: nil, max: nil
          call_options = nil
          call_options = Google::Gax::CallOptions.new page_token: token if token

          execute do
            paged_enum = instances.list_instance_configs project_path,
                                                         page_size: max,
                                                         options: call_options

            paged_enum.page.response
          end
        end

        def get_instance_config name
          execute do
            instances.get_instance_config instance_config_path(name)
          end
        end

        def list_databases instance_id, token: nil, max: nil
          call_options = nil
          call_options = Google::Gax::CallOptions.new page_token: token if token

          execute do
            paged_enum = databases.list_databases instance_path(instance_id),
                                                  page_size: max,
                                                  options: call_options

            paged_enum.page.response
          end
        end

        def get_database instance_id, database_id
          execute do
            databases.get_database database_path(instance_id, database_id)
          end
        end

        def create_database instance_id, database_id, statements: []
          execute do
            databases.create_database \
              instance_path(instance_id),
              "CREATE DATABASE `#{database_id}`",
              extra_statements: Array(statements)
          end
        end

        def drop_database instance_id, database_id
          execute do
            databases.drop_database database_path(instance_id, database_id)
          end
        end

        def get_database_ddl instance_id, database_id
          execute do
            databases.get_database_ddl database_path(instance_id, database_id)
          end
        end

        def update_database_ddl instance_id, database_id, statements: [],
                                operation_id: nil
          execute do
            databases.update_database_ddl \
              database_path(instance_id, database_id),
              Array(statements),
              operation_id: operation_id
          end
        end

        def get_database_policy instance_id, database_id
          execute do
            databases.get_iam_policy database_path(instance_id, database_id)
          end
        end

        def set_database_policy instance_id, database_id, new_policy
          execute do
            databases.set_iam_policy \
              database_path(instance_id, database_id), new_policy
          end
        end

        def test_database_permissions instance_id, database_id, permissions
          execute do
            databases.test_iam_permissions \
              database_path(instance_id, database_id), permissions
          end
        end

        def get_session session
          execute do
            service.get_session session
          end
        end

        def create_session database
          execute do
            service.create_session database
          end
        end

        def delete_session session
          execute do
            service.delete_session session
          end
        end

        def execute_sql session_path, sql, params: nil, transaction: nil
          input_params = nil
          input_param_types = nil
          unless params.nil?
            input_param_pairs = Convert.raw_to_params params
            input_params = Google::Protobuf::Struct.new(
              fields: Hash[input_param_pairs.map { |k, v| [k, v.first] }])
            input_param_types = Hash[
              input_param_pairs.map { |k, v| [k, v.last] }]
          end
          execute do
            service.execute_sql \
              session_path, sql, params: input_params,
                                 param_types: input_param_types,
                                 transaction: transaction && transaction.to_selector
          end
        end

        def streaming_execute_sql session_path, sql, params: nil, transaction: nil
          input_params = nil
          input_param_types = nil
          unless params.nil?
            input_param_pairs = Convert.raw_to_params params
            input_params = Google::Protobuf::Struct.new(
              fields: Hash[input_param_pairs.map { |k, v| [k, v.first] }])
            input_param_types = Hash[
              input_param_pairs.map { |k, v| [k, v.last] }]
          end
          execute do
            service.execute_streaming_sql \
              session_path, sql, params: input_params,
                                 param_types: input_param_types,
                                 transaction: transaction && transaction.to_selector
          end
        end

        def read_table session_path, table_name, columns, id: nil, limit: nil,
                                                          transaction: nil
          columns.map!(&:to_s)
          key_set = Google::Spanner::V1::KeySet.new(all: true)
          unless id.nil?
            key_list = Array(id).map do |i|
              Convert.raw_to_value(Array(i)).list_value
            end
            key_set = Google::Spanner::V1::KeySet.new(keys: key_list)
          end
          execute do
            service.read \
              session_path, table_name, columns, key_set,
              limit: limit, transaction: transaction && transaction.to_selector
          end
        end

        def streaming_read_table session_path, table_name, columns, id: nil,
                                 limit: nil, transaction: nil
          columns.map!(&:to_s)
          key_set = Google::Spanner::V1::KeySet.new(all: true)
          unless id.nil?
            key_list = Array(id).map do |i|
              Convert.raw_to_value(Array(i)).list_value
            end
            key_set = Google::Spanner::V1::KeySet.new(keys: key_list)
          end
          execute do
            service.streaming_read \
              session_path, table_name, columns, key_set,
              limit: limit, transaction: transaction && transaction.to_selector
          end
        end

        def commit session_path, mutations = [], transaction: nil
          execute do
            if transaction && transaction.transaction_id
              service.commit \
                session_path, mutations, transaction_id: transaction.transaction_id
            else
              tx_opts = Google::Spanner::V1::TransactionOptions.new(read_write:
                Google::Spanner::V1::TransactionOptions::ReadWrite.new)
              service.commit \
                session_path, mutations, single_use_transaction: tx_opts
            end
          end
        end

        def rollback session_path, transaction
          tx_id = transaction.transaction_id
          execute do
            service.rollback session: session_path, transaction_id: tx_id
          end
        end

        def inspect
          "#{self.class}(#{@project})"
        end

        protected

        def default_headers
          { "google-cloud-resource-prefix" => "projects/#{@project}" }
        end

        def default_options
          Google::Gax::CallOptions.new kwargs: default_headers
        end

        def project_path
          Admin::Instance::V1::InstanceAdminClient.project_path project
        end

        def instance_path name
          return name if name.to_s.include? "/"
          Admin::Instance::V1::InstanceAdminClient.instance_path(
            project, name)
        end

        def instance_config_path name
          return name if name.to_s.include? "/"
          Admin::Instance::V1::InstanceAdminClient.instance_config_path(
            project, name.to_s)
        end

        def database_path instance_id, database_id
          Admin::Database::V1::DatabaseAdminClient.database_path(
            project, instance_id, database_id)
        end

        def session_path instance_id, database_id, session_id
          V1::SpannerClient.session_path(
            project, instance_id, database_id, session_id)
        end

        def execute
          yield
        rescue Google::Gax::GaxError => e
          # GaxError wraps BadStatus, but exposes it as #cause
          raise Google::Cloud::Error.from_error(e.cause)
        end
      end
    end
  end
end
