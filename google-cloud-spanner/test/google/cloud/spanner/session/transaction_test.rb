# Copyright 2017 Google Inc. All rights reserved.
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

require "helper"

describe Google::Cloud::Spanner::ReadOnlyTransaction, :transaction, :mock_spanner do
  let(:instance_id) { "my-instance-id" }
  let(:database_id) { "my-database-id" }
  let(:session_id) { "session123" }
  let(:transaction_id) { "12345" }
  let(:session_grpc) { Google::Spanner::V1::Session.new name: session_path(instance_id, database_id, session_id) }
  let(:session) { Google::Cloud::Spanner::Session.from_grpc session_grpc, spanner.service }

  let(:strong_transaction_option) { 
    Google::Spanner::V1::TransactionOptions.new \
      read_only: Google::Spanner::V1::TransactionOptions::ReadOnly.new(strong: true)
  }
  let(:read_timestamp_time) { Time.now }
  let(:read_timestamp) do
    Google::Protobuf::Timestamp.new.tap do |value|
      value.from_time read_timestamp_time
    end
  end
  let(:timestamp_transaction_option) do
    Google::Spanner::V1::TransactionOptions.new \
      read_only: Google::Spanner::V1::TransactionOptions::ReadOnly.new(read_timestamp: read_timestamp)
  end
  let(:staleness_duration) { Google::Protobuf::Duration.new(seconds: 1, nanos: 2) }
  let(:staleness_transaction_option) do
    Google::Spanner::V1::TransactionOptions.new \
      read_only: Google::Spanner::V1::TransactionOptions::ReadOnly.new(exact_staleness: staleness_duration)
  end
  let(:read_write_transaction_option) do
    Google::Spanner::V1::TransactionOptions.new \
      read_write: Google::Spanner::V1::TransactionOptions::ReadWrite.new
  end

  let :results_hash do
    {
      metadata: {
        rowType: {
          fields: [
            { name: "id", type: { code: "INT64" } },
          ]
        },
        transaction: { id: Base64.strict_encode64(transaction_id) },
      },
     rows: [{
        values: [
          { stringValue: "1" },
        ]
      }
    ]}
  end
  let(:results_json) { results_hash.to_json }
  let(:results_grpc) { Google::Spanner::V1::ResultSet.decode_json results_json }

  let(:insert_id) { "2" }
  let(:mutation_hashes) {
    [{
      insert: {
        table: "my-table",
        columns: %w[ id ],
        values: [{
          values: [
            { stringValue: insert_id },
          ]
        }]
      }
    }]
  }
  let(:mutation_jsons) { mutation_hashes.map(&:to_json) }
  let(:mutations) { mutation_jsons.map {|json| Google::Spanner::V1::Mutation.decode_json json } }
  let(:commit_timestamp) { Time.now }
  let :commit_hash do
    {
      commit_timestamp: { seconds: commit_timestamp.to_i, nanos: commit_timestamp.nsec }
    }
  end
  let(:commit_json) { commit_hash.to_json }
  let(:commit_grpc) { Google::Spanner::V1::CommitResponse.decode_json commit_json }

  it "begins strong transaction on first read" do
    mock = Minitest::Mock.new
    keys = Google::Spanner::V1::KeySet.new(all: true)
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(begin: strong_transaction_option)]
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(id: transaction_id)]
    session.service.mocked_service = mock

    results = session.transaction(:strong) do |tx|
      tx.read "my-table", [:id], streaming: false
      tx.read "my-table", [:id], streaming: false
    end

    mock.verify

    assert_results results
  end

  it "begins read_timestamp transaction on first read" do
    mock = Minitest::Mock.new
    keys = Google::Spanner::V1::KeySet.new(all: true)
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(begin: timestamp_transaction_option)]
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(id: transaction_id)]
    session.service.mocked_service = mock

    results = session.transaction(:read_timestamp, read_timestamp_time) do |tx|
      tx.read "my-table", [:id], streaming: false
      tx.read "my-table", [:id], streaming: false
    end

    mock.verify

    assert_results results
  end

  it "begins exact_staleness transaction on first read" do
    mock = Minitest::Mock.new
    keys = Google::Spanner::V1::KeySet.new(all: true)
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(begin: staleness_transaction_option)]
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(id: transaction_id)]
    session.service.mocked_service = mock

    results = session.transaction(:exact_staleness, staleness_duration.seconds, staleness_duration.nanos) do |tx|
      tx.read "my-table", [:id], streaming: false
      tx.read "my-table", [:id], streaming: false
    end

    mock.verify

    assert_results results
  end

  it "begins read_write transaction on first read" do
    mock = Minitest::Mock.new
    keys = Google::Spanner::V1::KeySet.new(all: true)
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(begin: read_write_transaction_option)]
    mock.expect :read, results_grpc, [session.path, "my-table", ["id"], keys, limit: nil, transaction: Google::Spanner::V1::TransactionSelector.new(id: transaction_id)]
    mock.expect :commit, commit_grpc, [session.path, mutations, transaction_id: transaction_id]
    session.service.mocked_service = mock

    session.transaction(:read_write) do |tx|
      tx.read "my-table", [:id], streaming: false
      tx.read "my-table", [:id], streaming: false
      tx.insert "my-table", [{id: insert_id}]
    end

    mock.verify
  end

  it "begins read_write single_use transaction on first write" do
    mock = Minitest::Mock.new
    keys = Google::Spanner::V1::KeySet.new(all: true)
    mock.expect :commit, commit_grpc, [session.path, mutations, single_use_transaction: read_write_transaction_option]
    session.service.mocked_service = mock

    session.transaction(:read_write) do |tx|
      tx.insert "my-table", [{id: insert_id}]
    end

    mock.verify
  end

  private
  def assert_results results
    results.must_be_kind_of Google::Cloud::Spanner::Results
    results.wont_be :streaming?

    results.types.wont_be :nil?
    results.types.must_be_kind_of Hash
    results.types.keys.count.must_equal 1
    results.types[:id].must_equal          :INT64

    results.rows.count.must_equal 1
    row = results.rows.first
    row.must_be_kind_of Hash
    row.keys.must_equal [:id]
    row[:id].must_equal 1
  end
end
