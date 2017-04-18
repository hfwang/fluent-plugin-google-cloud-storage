# -*- coding: utf-8 -*-

require 'fluent/mixin/config_placeholders'
require 'fluent/mixin/plaintextformatter'
require 'fluent/log'

class Fluent::GoogleCloudStorageOutput < Fluent::TimeSlicedOutput
  Fluent::Plugin.register_output('google_cloud_storage', self)

  config_set_default :buffer_type, 'file'
  config_set_default :time_slice_format, '%Y%m%d'

  config_param :ignore_start_check_error, :bool, :default => false

  include Fluent::Mixin::ConfigPlaceholders

  config_param :service_email, :string
  config_param :service_pkcs12_path, :string
  config_param :service_pkcs12_password, :string, :default => "notasecret"
  config_param :project_id, :string
  config_param :bucket_id, :string
  config_param :path, :string

  config_param :compress, :default => nil do |val|
      unless ["gz", "gzip"].include?(val)
        raise ConfigError, "Unsupported compression algorithm '#{val}'"
      end
      val
  end

  # how many times of write failure before switch to standby namenode
  # by default it's 11 times that costs 1023 seconds inside fluentd,
  # which is considered enough to exclude the scenes that caused by temporary network fail or single datanode fail
  config_param :failures_before_use_standby, :integer, :default => 11

  include Fluent::Mixin::PlainTextFormatter

  config_param :default_tag, :string, :default => 'tag_missing'

  def initialize
    super
    require 'zlib'
    require 'net/http'
    require 'time'
    require 'google/api_client'
    require 'signet/oauth_2/client'
    require 'mime-types'
  end

  # Define `log` method for v0.10.42 or earlier
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  def call_google_api(params)
    # refresh_auth
    if @google_api_client.authorization.expired?
      @google_api_client.authorization.fetch_access_token!
    end
    return @google_api_client.execute(params)
  end

  def configure(conf)
    if conf['path']
      if conf['path'].index('%S')
        conf['time_slice_format'] = '%Y%m%d%H%M%S'
      elsif conf['path'].index('%M')
        conf['time_slice_format'] = '%Y%m%d%H%M'
      elsif conf['path'].index('%H')
        conf['time_slice_format'] = '%Y%m%d%H'
      end
    end

    super

    @client = prepare_client()
  end

  def prepare_client
    @google_api_client = Google::APIClient.new(
        :application_name => "fluent-plugin-google-cloud-storage",
        :application_version => "0.3.1")
    begin
      key = Google::APIClient::KeyUtils.load_from_pkcs12(
        @service_pkcs12_path, @service_pkcs12_password)
      @google_api_client.authorization = Signet::OAuth2::Client.new(
          token_credential_uri: "https://accounts.google.com/o/oauth2/token",
          audience: "https://accounts.google.com/o/oauth2/token",
          issuer: @service_email,
          scope: "https://www.googleapis.com/auth/devstorage.read_write",
          signing_key: key)
      @google_api_client.authorization.fetch_access_token!
    rescue Signet::AuthorizationError
      raise Fluent::ConfigError, "Error occurred authenticating with Google"
    end
    @storage_api = @google_api_client.discovered_api("storage", "v1")
    return @google_api_client
  end

  def start
    super
  end

  def shutdown
    super
  end

  def path_format(chunk_key)
    path = Time.strptime(chunk_key, @time_slice_format).strftime(@path)
    log.debug "GCS Path: #{path}"
    path
  end

  def send_data(path, data)
    mimetype = MIME::Types.type_for(path).first

    io = nil
    if ["gz", "gzip"].include?(@compress)
      io = StringIO.new("")
      writer = Zlib::GzipWriter.new(io)
      writer.write(data)
      writer.finish
      io.rewind
    else
      io = StringIO.new(data)
    end

    media = Google::APIClient::UploadIO.new(io, mimetype.content_type, File.basename(path))

    call_google_api(api_method: @storage_api.objects.insert,
                    parameters: {
                      uploadType: "multipart",
                      project: @project_id,
                      bucket: @bucket_id,
                      name: path
                    },
                    body_object: { contentType: media.content_type },
                    media: media)
  end

  def write(chunk)
    hdfs_path = path_format(chunk.key)

    send_data(hdfs_path, chunk.read)

    hdfs_path
  end
end
