require "base64"
require "openssl"

module Aliyun
  module Utils

    class << self
      def api_sign(key, verb, headers, resources)
        content_md5 = headers['Content-Md5'] || ""
        content_type = headers['Content-Type'] || ""
        date = headers['Date']

        cano_headers = headers.select { |k, v| k.start_with?("x-oss-") }
                         .map { |k, v| [k.downcase.strip, v.strip] }
                         .sort.map { |k, v| [k, v].join(":") + "\n" }.join

        cano_res = resources[:path] || "/"
        sub_res = (resources[:sub_res] || {})
                    .sort.map { |k, v| v ? [k, v].join("=") : k }.join("&")
        cano_res += "?#{sub_res}" unless sub_res.empty?

        string_to_sign =
        "#{verb}\n#{content_md5}\n#{content_type}\n#{date}\n" +
        "#{cano_headers}#{cano_res}"

        Base64.strict_encode64(
          OpenSSL::HMAC.digest('sha1', key, string_to_sign)
        )
      end
    end

  end # Utils
end # Aliyun
