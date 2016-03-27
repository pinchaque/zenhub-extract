#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require "psych"
require "csv"
require 'github_api'
require 'zenhub'
require 'tzinfo'

def date_puts(msg)
  puts("[#{Time.now.strftime("%F %T")}] #{msg}")
end

options = {
  config: File.expand_path("../../etc/config.yml", __FILE__),
  output: "output.csv",
  milestone: nil,
  start_date: nil,
  end_date: nil,
}
OptionParser.new do |opts|
  opts.banner = <<TXT
Usage: #{$0} [options]

Script that downloads issue data from GitHub and ZenHub to be able to plot
velocity and burndown. Pulls all issues belonging to the specified milestone,
or which were closed in the specified date range.

TXT
  opts.on("-c", "--config FILE", "Configuration file") do |file|
    options[:config] = file
  end
  opts.on("-o", "--output FILE", "Output CSV file") do |file|
    options[:output] = file
  end
  opts.on("-m", "--milestone name", "Milestone name") do |milestone|
    options[:milestone] = milestone
  end
  opts.on("-s", "--start_date date", "Start of date range for closed issues") do |date|
    options[:start_date] = DateTime.parse(date)
  end
  opts.on("-e", "--end_date date", "End of date range for closed issues") do |date|
    options[:end_date] = DateTime.parse(date)
  end
end.parse!

config = Psych.load_file(options[:config])

Github.configure do |c|
  c.basic_auth = [config["user"], config["password"]].join(":")
  c.user       = config["user"]
  c.repo       = config["repository"]
end

gh = Github.new

issues = {}

if options[:milestone]
  n = 0
  
  response = gh.issues.list(
    repo: config["repository"],
    filter: "all",
    state: "all",
    user: config["org"],
    milestone: options[:milestone])
    
  response.each_page do |iss|
    iss.each do |i| 
      issues[i.number] = i
      n += 1
    end
  end  
  date_puts("Found #{n} issues for milestone #{options[:milestone]}")
end

# get all tickets closed in the specified date range
if options[:start_date] && options[:end_date]
  n = 0
  
  # get our time strings in utc format
  tz = TZInfo::Timezone.get(config["time_zone"])
  st = tz.local_to_utc(options[:start_date])
  en = tz.local_to_utc(options[:end_date])
  
  response = gh.issues.list(
    repo: config["repository"],
    since: st.strftime("%FT%TZ"),
    filter: "all",
    state: "closed",
    user: config["org"])
    
  response.each_page do |iss|
    iss.each do |i| 
      next if i.closed_at.nil?
      closed_at = DateTime.parse(i.closed_at)
      
      if closed_at >= st && closed_at <= en
        issues[i.number] = i
        n += 1
      end
    end
  end  
  
  date_puts("Found #{n} issues for date range #{st} - #{en}")
end
    
# set up zenhub details
repo = gh.repos.get(config["org"], config["repository"])
zh = Zenhub.new(repo.id, config["zenhub_api_token"])

rows = issues.values.map do |iss|
  date_puts("Downloading Zenhub data for ##{iss.number} #{iss.title}")
  zhi = zh.issue(iss.number)
  {
    number: iss.number, 
    title: iss.title,
    state: iss.state,
    assignee: iss.assignee && iss.assignee.login,
    labels: iss.labels.map{ |x| x.name }.sort.join(","),
    milestone: iss.milestone && iss.milestone.title,
    created_at: iss.created_at,
    closed_at: iss.closed_at,
    estimate: zhi.fetch("estimate", {})["value"],
    pipeline: zhi.fetch("pipeline", {})["name"],
  }
end

abort("No issues found") if rows.empty?

date_puts("Writing #{rows.count} rows to #{options[:output]}")

CSV.open(options[:output], "wb") do |csv|
  csv << rows[0].keys
  rows.each { |r| csv << r.values }
end
