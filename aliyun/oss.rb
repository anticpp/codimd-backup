require "time"
require "net/http"
require_relative "utils"

module Aliyun
  module OSS

    OK = 0
    ERR_HTTP = 101

    class Client
      def initialize(endpoint, access_key_id, access_key_secret)
        @endpoint = endpoint
        @access_key_id = access_key_id
        @access_key_secret = access_key_secret
      end

      def put_object_from_file(bucket_name, object_name, filepath) 
        uri = URI("http://#{bucket_name}.#{@endpoint}/#{object_name}")
        res = Net::HTTP.start(uri.hostname, uri.port) { |http|
          # Prepare authorization
          headers = { 'Date'=>Time.now.httpdate,
              'Content-Type'=> "application/octet-stream"
          }
          resources = { :path=> "/#{bucket_name}/#{object_name}" }
          sig = Aliyun::Utils.api_sign(@access_key_secret, "PUT", headers, resources)
          headers["Authorization"] = "OSS #{@access_key_id}:#{sig}"
  
          # Make http request
          req = Net::HTTP::Put.new(uri)
          headers.each { |k, v| req[k]=v }
          req.body = File.read(filepath)

          http.request(req)
        }

        if !res.is_a?(Net::HTTPSuccess) then
          yield ERR_HTTP, res.message
        end

        yield OK, "Succ"
      end
    end # class Client

  end # OSS
end # Aliyun
