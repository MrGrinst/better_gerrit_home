require "rubiclifier"
require_relative "./api.rb"
require_relative "./server.rb"

class BetterGerritHome < Rubiclifier::BaseApplication
  def show_help
    puts
    puts("DESCRIPTION")
    puts
    puts("Usage:")
    puts("  better_gerrit_home --help                      | Shows this help menu")
    puts("  better_gerrit_home --setup                     | Runs setup")
    puts("  better_gerrit_home command --option <argument> | Executes command")
    puts
    exit
  end

  def server_class
    Server
  end

  def features
    [Rubiclifier::Feature::DATABASE, Rubiclifier::Feature::SERVER]
  end

  def settings
    @settings ||= [
      Rubiclifier::Setting.new("base_api_url", "base URL", explanation: "e.g. https://gerrit.google.com"),
      Rubiclifier::Setting.new("username", "account username"),
      Rubiclifier::Setting.new("password", "account password", explanation: "input hidden", is_secret: true),
      Rubiclifier::Setting.new("account_id", "account ID", explanation: -> {"check #{Api.base_api_url}/settings/"})
    ]
  end

  def data_directory
    "~/.better_gerrit_home"
  end

  def migrations_location
    "#{File.expand_path(File.dirname(__FILE__) + "/..")}/migrations.rb"
  end
end
