require "rubiclifier"
require "base64"

class GithubApi < Rubiclifier::BaseApi
  def self.login_and_get_api_token
    nil # return this because there is no username/password for Github
  end

  def self.invalid_credentials_error
    Rubiclifier::Notification.new(
      "Incorrect Github Token",
      "Trying running `better_gerrit_home --setup` again."
    ).send
    sleep(120)
    exit
  end

  def self.all_code_changes
    wrap_with_authentication do
      get("/orgs/#{org}/issues?filter=subscribed&sort=updated&per_page=100&state=all", { headers: headers })
    end.parsed_response
  end

  def self.inject_new_test_status(pr)
    attrs = wrap_with_authentication do
      get("/repos/#{org}/#{pr[:project]}/commits/#{pr[:commit_id]}/check-runs", { headers: headers })
    end.parsed_response
    last_run = attrs["check_runs"].last
    if last_run && last_run["conclusion"]
      if last_run["conclusion"] == "success"
        pr[:reviews][:v][:status] = "+2"
        pr[:reviews][:v][:person] = "Github Actions"
        pr[:reviews][:v][:is_bot] = true
      elsif last_run["conclusion"] == "failure"
        pr[:reviews][:v][:status] = "-2"
        pr[:reviews][:v][:person] = "Github Actions"
        pr[:reviews][:v][:is_bot] = true
      end
      true
    end
    false
  end

  def self.inject_old_test_status(pr)
    attrs = wrap_with_authentication do
      get("/repos/#{org}/#{pr[:project]}/statuses/#{pr[:commit_id]}", { headers: headers })
    end.parsed_response
    last_run = attrs.first
    if last_run
      if last_run["state"] == "success"
        pr[:reviews][:v][:status] = "+2"
        pr[:reviews][:v][:person] = "Github Status"
        pr[:reviews][:v][:is_bot] = true
      elsif last_run["state"] == "error"
        pr[:reviews][:v][:status] = "-2"
        pr[:reviews][:v][:person] = "Github Status"
        pr[:reviews][:v][:is_bot] = true
      end
    end
  end

  def self.inject_reviews(pr)
    attrs = wrap_with_authentication do
      get("/repos/#{org}/#{pr[:project]}/pulls/#{pr[:id_frd]}/reviews", { headers: headers })
    end.parsed_response.select { |j| j["commit_id"] == pr[:commit_id] }
    attrs = attrs.group_by { |r| r["user"]["login"] }
    attrs = attrs.inject({}) { |acc, (u, reviews)| acc[u] = reviews.last; acc }
    if attrs.any? { |_, r| r["state"] == "REJECTED" }
      u, r = attrs.find { |u, r| r["state"] == "REJECTED" }
      pr[:reviews][:cr][:status] = "-2"
      pr[:reviews][:cr][:person] = u
    elsif attrs.any? { |_, r| r["state"] == "APPROVED" }
      u, r = attrs.find { |u, r| r["state"] == "APPROVED" }
      pr[:reviews][:cr][:status] = "+2"
      pr[:reviews][:cr][:person] = u
    end
  end

  def self.inject_info(pr, sizer)
    attrs = wrap_with_authentication do
      get("/repos/#{org}/#{pr[:project]}/pulls/#{pr[:id_frd]}", { headers: headers })
    end.parsed_response
    pr[:size] = sizer.call(attrs["additions"] + attrs["deletions"])
    pr[:commit_id] = attrs["head"]["sha"]
  end

  def self.headers
    {
      "Authorization" => "Basic #{Base64.strict_encode64("#{username}:#{api_token}")}",
      "User-Agent" => "Ruby Httparty gem",
      "Accept" => "application/vnd.github.antiope-preview+json"
    }
  end

  def self.api_token_db_key
    "github_token"
  end

  def self.base_api_url
    "https://api.github.com"
  end

  def self.org
    @org ||= Rubiclifier::DB.get_setting("github_org")
  end

  def self.username
    @username ||= Rubiclifier::DB.get_setting("github_username")
  end
end
