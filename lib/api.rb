require "rubiclifier"

class HTTParty::Parser
  def json
    JSON.parse(body.gsub(")]}'", ""))
  end
end

class Api < Rubiclifier::BaseApi
  def self.login_and_get_api_token
    res = post("/login/", {
      body: "username=#{username}&password=#{URI.escape(password)}&rememberme=1",
      headers: {
        "Content-Type" => "application/x-www-form-urlencoded",
      },
      follow_redirects: false
    })
    set_cookie_header = res.headers["set-cookie"] || ""
    set_cookie_header.match("GerritAccount=(.*?);")&.to_a&.fetch(1)
  end

  def self.invalid_credentials_error
    sleep(120)
    exit
  end

  def self.all_code_changes
    wrap_with_authentication do
      get("/changes/?S=0&q=is%3Aopen%20owner%3Aself%20-is%3Awip%20-is%3Aignored%20limit%3A25&q=is%3Aopen%20owner%3Aself%20is%3Awip%20limit%3A25&q=is%3Aopen%20-owner%3Aself%20-is%3Awip%20-is%3Aignored%20reviewer%3Aself%20limit%3A25&q=is%3Aclosed%20-is%3Aignored%20%28-is%3Awip%20OR%20owner%3Aself%29%20%28owner%3Aself%20OR%20reviewer%3Aself%29%20-age%3A4w%20limit%3A10&o=DETAILED_ACCOUNTS&o=MESSAGES&o=LABELS", {
        headers: {
          "Cookie" => "GerritAccount=#{api_token};"
        }
      })
    end.parsed_response
  end

  def self.api_token_db_key
    "api_token"
  end

  def self.base_api_url_db_key
    "base_api_url"
  end

  def self.username
    @username ||= Rubiclifier::DB.get_setting("username")
  end

  def self.password
    @password ||= Rubiclifier::DB.get_setting("password")
  end

  def self.account_id
    @account_id ||= Rubiclifier::DB.get_setting("account_id")
  end
end
