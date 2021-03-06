require 'core/auth/client'
require 'httparty'
require 'json'
require 'uri'
require_relative 'utils'

# Class to query an obe site and find the nbe details related to it
class PageFinder
  attr_accessor :domain, :email, :password, :auth

  def initialize(_domain, _email, _password, _verify_ssl_cert, verbose=false)
    @email = _email
    @password = _password
    @domain = _domain
    @verify_ssl_cert = _verify_ssl_cert
    verbosity = verbose ? Logger::DEBUG : Logger::INFO
    @log = Utils::Log.new(true, true, verbosity)
    @auth = Core::Auth::Client.new(@domain, email: @email, password: @password, verify_ssl_cert: @verify_ssl_cert)
    fail('Authentication failed') unless @auth.logged_in?
  end

  # function to take a obe uri and id and get the nbe id and page id
  def get_nbe_page_id_from_obe_uri(obe_uri_in, obe_id)
    obe_uri = URI(obe_uri_in)
    obe_uri_api = "https://#{obe_uri.host}/api/migrations/#{obe_id}"
    @log.debug("Querying: #{obe_uri_api} for a New UX Id")

    new_ux_id = get_nbe_id_from_obe_domain(obe_uri_api)

    if new_ux_id.nil?
      @log.info("New UX Id not found")
    else
      @log.info("New UX Id: #{new_ux_id}")
      new_page = "https://#{obe_uri.host}/view/#{new_ux_id}"

      begin
        @log.debug("Querying: #{new_page} for the contents of the New UX page")
        response = http_get_response(new_page)
        @log.info("Page: #{new_page} found.")
        new_page
      rescue
        @log.error("Page: #{new_page} not found.")
        nil
      end
    end
  end

  # get the nbe 4x4 based on an OBE URL
  def get_nbe_id_from_obe_domain(obe_uri)
    uri = URI(obe_uri)
    new_ux_id

    response = http_get_response(uri)
    parsed = response.parsed_response

    @log.debug("New UX Id: #{parsed["nbeId"]}")

    if parsed["nbeId"].nil? || parsed["nbeId"].empty?
    else
      new_ux_id = get_page_id_for_given_nbe_id(uri, parsed["nbeId"])
    end

    new_ux_id
  end

  private

  # function to get the page id from a nbe id
  def get_page_id_for_given_nbe_id(uri, nbe_id)
    new_uri = "https://#{uri.host}/metadata/v1/dataset/#{nbe_id}/pages.json"

    response = http_get_response(new_uri)
    parsed = response.parsed_response

    begin
      @log.info("PageId: #{parsed["publisher"][0]["pageId"]}")
      parsed["publisher"][0]["pageId"]
    rescue
      @log.error("PageId not found")
    end
  end

  def http_get_response(uri)
    @log.debug("Auth: #{@auth.cookie}\nCalling: #{uri.to_s}")
    response = HTTParty.get(uri, headers: {'Cookie' => @auth.cookie})
  end
end
