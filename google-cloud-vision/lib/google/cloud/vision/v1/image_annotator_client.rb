# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# EDITING INSTRUCTIONS
# This file was generated from the file
# https://github.com/googleapis/googleapis/blob/master/google/cloud/vision/v1/image_annotator.proto,
# and updates to that file get reflected here through a refresh process.
# For the short term, the refresh process will only be runnable by Google
# engineers.
#
# The only allowed edits are to method and file documentation. A 3-way
# merge preserves those additions if the generated source changes.

require "json"
require "pathname"

require "google/gax"
require "google/cloud/vision/v1/image_annotator_pb"

module Google
  module Cloud
    module Vision
      module V1
        # Service that performs Google Cloud Vision API detection tasks over client
        # images, such as face, landmark, logo, label, and text detection. The
        # ImageAnnotator service returns detected entities from the images.
        #
        # @!attribute [r] image_annotator_stub
        #   @return [Google::Cloud::Vision::V1::ImageAnnotator::Stub]
        class ImageAnnotatorClient
          attr_reader :image_annotator_stub

          # The default address of the service.
          SERVICE_ADDRESS = "vision.googleapis.com".freeze

          # The default port of the service.
          DEFAULT_SERVICE_PORT = 443

          DEFAULT_TIMEOUT = 30

          # The scopes needed to make gRPC calls to all of the methods defined in
          # this service.
          ALL_SCOPES = [
            "https://www.googleapis.com/auth/cloud-platform"
          ].freeze

          # @param service_path [String]
          #   The domain name of the API remote host.
          # @param port [Integer]
          #   The port on which to connect to the remote host.
          # @param channel [Channel]
          #   A Channel object through which to make calls.
          # @param chan_creds [Grpc::ChannelCredentials]
          #   A ChannelCredentials for the setting up the RPC client.
          # @param client_config[Hash]
          #   A Hash for call options for each method. See
          #   Google::Gax#construct_settings for the structure of
          #   this data. Falls back to the default config if not specified
          #   or the specified config is missing data points.
          # @param timeout [Numeric]
          #   The default timeout, in seconds, for calls made through this client.
          def initialize \
              service_path: SERVICE_ADDRESS,
              port: DEFAULT_SERVICE_PORT,
              channel: nil,
              chan_creds: nil,
              scopes: ALL_SCOPES,
              client_config: {},
              timeout: DEFAULT_TIMEOUT,
              app_name: nil,
              app_version: nil,
              lib_name: nil,
              lib_version: ""
            # These require statements are intentionally placed here to initialize
            # the gRPC module only when it's required.
            # See https://github.com/googleapis/toolkit/issues/446
            require "google/gax/grpc"
            require "google/cloud/vision/v1/image_annotator_services_pb"


            if app_name || app_version
              warn "`app_name` and `app_version` are no longer being used in the request headers."
            end

            google_api_client = "gl-ruby/#{RUBY_VERSION}"
            google_api_client << " #{lib_name}/#{lib_version}" if lib_name
            google_api_client << " gapic/0.6.8 gax/#{Google::Gax::VERSION}"
            google_api_client << " grpc/#{GRPC::VERSION}"
            google_api_client.freeze

            headers = { :"x-goog-api-client" => google_api_client }
            client_config_file = Pathname.new(__dir__).join(
              "image_annotator_client_config.json"
            )
            defaults = client_config_file.open do |f|
              Google::Gax.construct_settings(
                "google.cloud.vision.v1.ImageAnnotator",
                JSON.parse(f.read),
                client_config,
                Google::Gax::Grpc::STATUS_CODE_NAMES,
                timeout,
                errors: Google::Gax::Grpc::API_ERRORS,
                kwargs: headers
              )
            end
            @image_annotator_stub = Google::Gax::Grpc.create_stub(
              service_path,
              port,
              chan_creds: chan_creds,
              channel: channel,
              scopes: scopes,
              &Google::Cloud::Vision::V1::ImageAnnotator::Stub.method(:new)
            )

            @batch_annotate_images = Google::Gax.create_api_call(
              @image_annotator_stub.method(:batch_annotate_images),
              defaults["batch_annotate_images"]
            )
          end

          # Service calls

          # Run image detection and annotation for a batch of images.
          #
          # @param requests [Array<Google::Cloud::Vision::V1::AnnotateImageRequest>]
          #   Individual image annotation requests for this batch.
          # @param options [Google::Gax::CallOptions]
          #   Overrides the default settings for this call, e.g, timeout,
          #   retries, etc.
          # @return [Google::Cloud::Vision::V1::BatchAnnotateImagesResponse]
          # @raise [Google::Gax::GaxError] if the RPC is aborted.
          # @example
          #   require "google/cloud/vision/v1/image_annotator_client"
          #
          #   ImageAnnotatorClient = Google::Cloud::Vision::V1::ImageAnnotatorClient
          #
          #   image_annotator_client = ImageAnnotatorClient.new
          #   requests = []
          #   response = image_annotator_client.batch_annotate_images(requests)

          def batch_annotate_images \
              requests,
              options: nil
            req = Google::Cloud::Vision::V1::BatchAnnotateImagesRequest.new({
              requests: requests
            }.delete_if { |_, v| v.nil? })
            @batch_annotate_images.call(req, options)
          end
        end
      end
    end
  end
end
