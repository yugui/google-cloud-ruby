# Copyright 2014 Google Inc. All rights reserved.
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


require "json"
require "signet/oauth_2/client"
require "forwardable"
require "googleauth"

module Google
  module Cloud
    ##
    # @private
    # Represents the OAuth 2.0 signing logic.
    # This class is intended to be inherited by API-specific classes
    # which overrides the SCOPE constant.
    class Credentials
      TOKEN_CREDENTIAL_URI = "https://accounts.google.com/o/oauth2/token"
      AUDIENCE = "https://accounts.google.com/o/oauth2/token"
      SCOPE = []
      PATH_ENV_VARS = %w(GOOGLE_CLOUD_KEYFILE GCLOUD_KEYFILE)
      JSON_ENV_VARS = %w(GOOGLE_CLOUD_KEYFILE_JSON GCLOUD_KEYFILE_JSON)
      DEFAULT_PATHS = ["~/.config/gcloud/application_default_credentials.json"]

      attr_accessor :client

      ##
      # Delegate client methods to the client object.
      extend Forwardable
      def_delegators :@client,
                     :token_credential_uri, :audience,
                     :scope, :issuer, :signing_key

      def initialize keyfile, scope: nil
        verify_keyfile_provided! keyfile
        if keyfile.is_a? Signet::OAuth2::Client
          @client = keyfile
        elsif keyfile.is_a? Hash
          hash = stringify_hash_keys keyfile
          hash["scope"] ||= scope
          @client = init_client hash
        else
          verify_keyfile_exists! keyfile
          json = JSON.parse ::File.read(keyfile)
          json["scope"] ||= scope
          @client = init_client json
        end
        @client.fetch_access_token!
      end

      ##
      # Returns the default credentials.
      #
      def self.default scope: nil
        env  = ->(v) { ENV[v] }
        json = ->(v) { JSON.parse ENV[v] rescue nil unless ENV[v].nil? }
        path = ->(p) { ::File.file? p }

        # First try to find keyfile file from environment variables.
        self::PATH_ENV_VARS.map(&env).compact.select(&path)
          .each do |file|
            return new file, scope: scope
          end
        # Second try to find keyfile json from environment variables.
        self::JSON_ENV_VARS.map(&json).compact.each do |hash|
          return new hash, scope: scope
        end
        # Third try to find keyfile file from known file paths.
        self::DEFAULT_PATHS.select(&path).each do |file|
          return new file, scope: scope
        end
        # Finally get instantiated client from Google::Auth.
        scope ||= self::SCOPE
        client = Google::Auth.get_application_default scope
        new client
      end

      protected

      ##
      # Verify that the keyfile argument is provided.
      def verify_keyfile_provided! keyfile
        fail "You must provide a keyfile to connect with." if keyfile.nil?
      end

      ##
      # Verify that the keyfile argument is a file.
      def verify_keyfile_exists! keyfile
        exists = ::File.file? keyfile
        fail "The keyfile '#{keyfile}' is not a valid file." unless exists
      end

      ##
      # Initializes the Signet client.
      def init_client keyfile
        client_opts = client_options keyfile
        Signet::OAuth2::Client.new client_opts
      end

      ##
      # returns a new Hash with string keys instead of symbol keys.
      def stringify_hash_keys hash
        Hash[hash.map { |k, v| [k.to_s, v] }]
      end

      def client_options options
        # Keyfile options have higher priority over constructor defaults
        options["token_credential_uri"] ||= self.class::TOKEN_CREDENTIAL_URI
        options["audience"]             ||= self.class::AUDIENCE
        options["scope"]                ||= self.class::SCOPE

        # client options for initializing signet client
        { token_credential_uri: options["token_credential_uri"],
          audience: options["audience"],
          scope: Array(options["scope"]),
          issuer: options["client_email"],
          signing_key: OpenSSL::PKey::RSA.new(options["private_key"]) }
      end
    end
  end
end
