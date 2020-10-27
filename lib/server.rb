require "rubiclifier"
require_relative "./gerrit_api.rb"
require_relative "./github_api.rb"
require "byebug"
require "time"

class Server < Rubiclifier::Server
  def self.hydrate
    set :public_folder, "#{File.expand_path(File.dirname(__FILE__) + "/..")}/public"
    set :port, 5541
  end

  get '/base_api_url' do
    GerritApi.base_api_url
  end

  get '/changes' do
    my_gerrit_wips = nil
    my_gerrit_changes = nil
    gerrit_others = nil
    gerrit_closed = nil
    all_github_prs = nil
    threads = []
    threads << Thread.new do
      my_gerrit_wips, my_gerrit_changes, gerrit_others, gerrit_closed = GerritApi.all_code_changes
    end
    threads << Thread.new do
      all_github_prs = GithubApi.all_code_changes.select { |pr| !!pr["pull_request"] }.map { |j| parse_raw_github_change(j) }
    end
    threads.each { |thr| thr.join }
    my_github_prs, github_others, github_closed = split_github_prs(all_github_prs)
    extra_info_threads = (my_github_prs + github_others).map do |pr|
      Thread.new do
        GithubApi.inject_info(pr, ->(total) { size(total) } )
        is_new = GithubApi.inject_new_test_status(pr)
        GithubApi.inject_old_test_status(pr) unless is_new
        GithubApi.inject_reviews(pr)
      end
    end
    extra_info_threads.each { |thr| thr.join }
    {
      mine: sort_by_updated((my_gerrit_wips + my_gerrit_changes)
              .map { |j| parse_raw_gerrit_change(j) } + my_github_prs),
      others: sort_by_updated(gerrit_others.map { |j| parse_raw_gerrit_change(j) } + github_others),
      closed: sort_by_updated(gerrit_closed.map { |j| parse_raw_gerrit_change(j) } + github_closed)
    }.to_json
  end

  private

  def parse_raw_gerrit_change(json)
    total = json["insertions"] + json["deletions"]
    {
      id: "#{GerritApi.base_api_url}/c/#{json["project"]}/+/#{json["_number"]}",
      owner_name: json["owner"]["name"],
      owner_email: json["owner"]["email"],
      project: json["project"],
      subject: json["subject"],
      updated_at: json["updated"],
      status: patch_status(json),
      size: size(total),
      reviews: reviews(json),
      changed_after_self_activity: changed_after_self_activity(json),
      github: false
    }
  end

  def parse_raw_github_change(json)
    {
      id: json["pull_request"]["html_url"],
      id_frd: json["pull_request"]["url"].match(/\d+$/)[0],
      owner_name: json["user"]["login"],
      owner_email: nil,
      project: json["repository"]["name"],
      subject: json["title"],
      updated_at: json["updated_at"],
      status: json["state"] == "closed" ? "Merged" : "-",
      size: 0,
      reviews: { cr: {}, qa: {}, pr: {}, v: {} },
      changed_after_self_activity: nil,
      commit_id: nil,
      github: true
    }
  end

  def split_github_prs(all_prs)
    mine = all_prs.select {   |p| p[:owner_name] == GithubApi.username && p[:status] == "-" }
    others = all_prs.select { |p| p[:owner_name] != GithubApi.username && p[:status] == "-" }
    closed = all_prs.select { |p| p[:status] == "Merged" }
    [mine, others, closed]
  end

  def sort_by_updated(list)
    list.sort { |a, b| DateTime.parse(b[:updated_at]) <=> DateTime.parse(a[:updated_at]) }
  end

  def patch_status(json)
    if json["status"] == "MERGED"
      "Merged"
    elsif json["status"] == "ABANDONED"
      "Abandoned"
    elsif !json["mergeable"]
      "Merge Conflict"
    else
      "-"
    end
  end

  def size(total)
    if total >= 5000
      100
    else
      ((Math.log([total, 2].max / 2, 10) / Math.log(5000, 10)).round(2) * 100).to_i
    end
  end

  def reviews(json)
    {
      cr: review(json["labels"]["Code-Review"]),
      pr: review(json["labels"]["Product-Review"] || {}, true),
      qa: review(json["labels"]["QA-Review"], true),
      v: review(json["labels"]["Verified"]),
    }
  end

  def review(json, only_goes_to_one = false)
    status = nil
    person = nil
    id = nil
    if json.key?("rejected")
      status = only_goes_to_one ? "-1" : "-2"
      person = json["rejected"]["name"]
      id = json["rejected"]["_account_id"]
    elsif json.key?("disliked")
      status = "-1"
      person = json["disliked"]["name"]
      id = json["disliked"]["_account_id"]
    elsif json.key?("recommended")
      status = "+1"
      person = json["recommended"]["name"]
      id = json["recommended"]["_account_id"]
    elsif json.key?("approved")
      status = only_goes_to_one ? "+1" : "+2"
      person = json["approved"]["name"]
      id = json["approved"]["_account_id"]
    end
    {
      status: status,
      person: person,
      is_self: id&.to_s == GerritApi.account_id,
      is_bot: !!person&.match(/(Service Cloud Jenkins|Gergich \(Bot\))/)
    }
  end

  def changed_after_self_activity(json)
    messages_without_bots = json["messages"].select { |m| !m["author"]["name"].match(/(Service Cloud Jenkins|Gergich \(Bot\))/) }
    self_has_activity = messages_without_bots.any? { |m| m["author"]["_account_id"].to_s == GerritApi.account_id }
    last_activity_is_self = messages_without_bots.last["author"]["_account_id"].to_s == GerritApi.account_id
    self_has_activity && !last_activity_is_self
  end
end
