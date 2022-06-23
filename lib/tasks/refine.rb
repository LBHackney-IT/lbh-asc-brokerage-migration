require 'httpclient'
require 'cgi'
require 'json'
require "addressable/uri"

class Refine
  class ProjectNotFound < Exception
    attr_reader :project_id, :server

    def initialize(message, project_id:, server:)
      super(message)
      @project_id = project_id
      @server = server
    end

    def to_s
      super + " (#{@server})"
    end
  end

  attr_reader :project_name
  attr_reader :project_id

  def self.get_all_project_metadata(server: "http://127.0.0.1:3333")
    uri = "#{server}/command/core/get-all-project-metadata"
    response = HTTPClient.new().get(uri)
    JSON.parse(response.body)
  end

  def initialize(opts = {}, &block)
    @http_client_config = block
    @server = opts["server"] || "http://127.0.0.1:3333"

    @throws_exceptions = opts["throws_exceptions"] === false ? false : true

    if opts["file_name"] && !opts["file_name"].empty? && opts["project_name"] && !opts["project_name"].empty?
      project_name = CGI.escape(opts["project_name"])
      @project_id = create_project(project_name, opts["file_name"], opts['options'], opts['format'])
      @project_name = project_name if @project_id
    else
      @project_id = opts["project_id"]

      metadata = self.get_project_metadata
      if metadata['status'] == 'error'
        raise ProjectNotFound.new(metadata['message'], project_id: @project_id, server: @server)
      else
        @project_name = CGI.escape(metadata["name"])
      end
    end
  end

  def get_csrf_token()
    uri = @server + '/command/core/get-csrf-token'
    response = client.get(uri)
    token = JSON.parse(response.body)
    token['token']
  end

  def create_project(project_name, file_name, options = {}, format = 'text/line-based/*sv')
    uri = @server + "/command/core/create-project-from-upload?csrf_token=" + get_csrf_token
    project_id = false
    File.open(file_name) do |file|
      body = {
        'project-file' => file,
        'project-name' => project_name
      }
      body['options'] = options
      body['format'] = format

      response = client.post(uri, body: body, header: {"Content-Type" => "multipart/form-data; charset=utf-8; boundary=#{create_boundary}"})
      url = response.header['Location']
      unless url == []
        project_id = CGI.parse(url[0].split('?')[1])['project'][0]
      end
    end
    raise "Error creating project: #{response}" unless project_id
    project_id
  end

  def apply_operations(file_name_or_string)
    if File.exist?(file_name_or_string)
      operations = File.read(file_name_or_string)
    else
      operations = file_name_or_string
    end

    call('apply-operations', 'operations' => operations)
  end

  def export_rows(opts={})
    format = opts["format"] || 'tsv'
    uri = @server + "/command/core/export-rows/#{@project_name}.#{format}"

    body = {
      'engine' => {
        "facets" => opts["facets"] || [],
        "mode" => "row-based"
      }.to_json,
      'options' => opts["options"] || '',
      'project' => @project_id,
      'format' => format
    }

    @response = client.post(uri, body)
    @response.content
  end

  def delete_project
    uri = @server + "/command/core/delete-project"
    body = {
      'project' => @project_id
    }
    @response = client.post(uri, body)
    JSON.parse(@response.content)['code'] rescue false
  end

  # this pattern is pulled from mailchimp/mailchimp-gem

  def call(method, params = {})
    uri = "#{@server}/command/core/#{method}?csrf_token=" + get_csrf_token
    params = { "project" => @project_id }.merge(params)
    response = if method.start_with?('get-')
                 client.get(uri, params)
               else
                 client.post(uri, params)
               end

    begin
      response = JSON.parse(response.body)
    rescue
      response = JSON.parse('[' + response.body + ']').first
    end

    if @throws_exceptions && response.is_a?(Hash) && response["code"] && response["code"] == "error"
      raise "API Error: #{response}"
    end

    response
  end

  def link_to_facets(*column_names)
    uri = Addressable::URI.parse("#{@server}/project")

    facet = facet_parameters(*column_names)

    json_facet=JSON::dump(facets: facet).gsub(' ', "\t")

    uri.query = Addressable::URI::form_encode({project: @project_id, ui: json_facet})

    uri.to_s.gsub("%09", "%20")

  end

  def compute_facet(*column_names)

    formatted = column_names.map do |column|
      expression, sort_by, invert = facet_opts(column.values.first)
      {
        "columnName" => column.keys.first,
        "expression" => expression,
        "name" => column.keys.first,
        "invert" => invert,
        "sort" => sort_by,
        "selection" => []
      }
    end

    json_facet = JSON::dump(facets: formatted)

    openrefine_response = compute_facets("engine" => json_facet)

    openrefine_response.fetch("facets").map do |facet|

      if facet.key?("choices")

        choices_hash = facet.fetch("choices").map do |h|
          Hash[%w(value label count selected).zip([h["v"]["v"], h["v"]["l"], h["c"], h["s"]])]
        end

        Hash[%w(columnName name expression choices).zip([facet.fetch("columnName"), facet.fetch("name"), facet.fetch("expression"), choices_hash])]
      elsif facet.key?("error")

        Hash[%w(columnName name expression error).zip([facet.fetch("columnName"), facet.fetch("name"), facet.fetch("expression"), facet.fetch("error")])]
      end

    end

  end

  def facet_parameters(*column_names)
    column_names.map do |column|
      case column when String then
                    {
                      "c" => {
                        "columnName" => column,
                        "expression"=>"value",
                        "name"=> column,
                        "invert"=> false
                      },
                      "o" => {
                        "sort" => "name"
                      }
                    }
      when Hash
        expression, sort_by, invert = facet_opts(column.values.first)

        {
          "c" => {
            "columnName" => column.keys.first,
            "expression"=> expression,
            "name"=> column.keys.first,
            "invert" => invert
          },
          "o" => {
            "sort" => sort_by
          }
        }
      end
    end
  end



  def method_missing(method, *args)
    # translate: get_column_info --> get-column-info
    call(method.to_s.gsub('_', '-'), *args)
  end

  protected

  def create_boundary
    Digest::SHA1.hexdigest(Time.now.to_s)
  end

  def facet_opts(opts_array)
    if opts_array.is_a? String
      expression_present = opts_array.include? "value"
      expression = expression_present ? opts_array : "value"
    else
      expression_present = opts_array[0].include? "value"
      expression = expression_present ? opts_array[0] : "value"
    end

    sort_by = opts_array.include? "sort_count"
    invert = opts_array.include? "invert"

    sort_by = sort_by ? "count" : "name"
    invert = invert ? true : false

    return escape_backticks(expression), sort_by, invert
  end

  def escape_backticks(string)
    string.gsub('//','////')
  end

  def client
    @client ||= HTTPClient.new(&@http_client_config)
  end

end
