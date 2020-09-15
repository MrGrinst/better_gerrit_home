require "rubiclifier"
require_relative "./api.rb"
require "byebug"

class Server < Rubiclifier::Server
  def self.hydrate
    set :public_folder, "#{File.expand_path(File.dirname(__FILE__) + "/..")}/public"
    set :port, 5541
  end

  get '/base_api_url' do
    Api.base_api_url
  end

  get '/changes' do
    my_wips, my_changes, others, closed = Api.all_code_changes
    {
      mine: (my_wips + my_changes).map { |j| parse_raw_change(j) },
      others: others.map { |j| parse_raw_change(j) },
      closed: closed.map { |j| parse_raw_change(j) }
    }.to_json
  end

  private

  def parse_raw_change(json)
    {
      id: json["_number"].to_s,
      owner_name: json["owner"]["name"],
      owner_email: json["owner"]["email"],
      project: json["project"],
      subject: json["subject"],
      updated_at: json["updated"],
      status: patch_status(json),
      size: size(json),
      reviews: reviews(json),
      changed_after_self_activity: changed_after_self_activity(json)
    }
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

  def size(json)
    total = json["insertions"] + json["deletions"]
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
      is_self: id&.to_s == Api.account_id,
      is_bot: !!person&.match(/(Service Cloud Jenkins|Gergich \(Bot\))/)
    }
  end

  def changed_after_self_activity(json)
    messages_without_bots = json["messages"].select { |m| !m["author"]["name"].match(/(Service Cloud Jenkins|Gergich \(Bot\))/) }
    self_has_activity = messages_without_bots.any? { |m| m["author"]["_account_id"].to_s == Api.account_id }
    last_activity_is_self = messages_without_bots.last["author"]["_account_id"].to_s == Api.account_id
    self_has_activity && !last_activity_is_self
  end
end
