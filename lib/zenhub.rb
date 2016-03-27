require 'rest-client'
require 'json'

class Zenhub
  attr_accessor :repo_id, :auth_token, :timeout
  
  def initialize(repo_id, auth_token)
    @repo_id = repo_id
    @auth_token = auth_token
    @timeout = 10
  end
  
  # Gets data for single issue
  # Return looks like: {"estimate"=>{"value"=>5}, "plus_ones"=>[], "pipeline"=>{"name"=>"Backlog"}}
  def issue(issue_num)
    rest_get("/issues/#{issue_num}")
  end
  
  private
  
  def base_url
    "https://api.zenhub.io/p1/repositories/#{@repo_id}"
  end
  
  def rest_get(path)
    with_retry(5, 6) do
      url = base_url + path
      headers = { "X-Authentication-Token" => @auth_token }
      resp = RestClient::Request.execute(
        method: :get, 
        url: url,
        timeout: @timeout, 
        headers: headers)
      JSON.parse resp.body
    end
  end
  
  def with_retry(max_retries, pause, &block)
    retried = 0
    begin
      yield
    rescue StandardError => ex
      raise unless ex.response.code == 403 # api rate limit reached
      raise unless (retried += 1) <= max_retries # enough retries
      secs_until_reset = ex.response.headers[:x_ratelimit_reset].to_i - Time.now.to_i + 1
      sleep([secs_until_reset, pause].max)
      retry
    end
  end
end
