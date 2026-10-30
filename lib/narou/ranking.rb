# frozen_string_literal: true

require "date"
require "json"
require "net/http"
require "uri"
require "thread"

module Narou
  # Read-only access to the public ranking and novel metadata APIs.
  class Ranking
    RANK_URL = "https://api.syosetu.com/rank/rankget/"
    NOVEL_URL = "https://api.syosetu.com/novelapi/api/"
    LIMIT = 100
    CACHE_SECONDS = 3600
    @cache = {}
    @mutex = Mutex.new

    def self.fetch(date:, kind:, registered: [])
      parsed = Date.iso8601(date)
      raise ArgumentError, "ランキング種別が不正です" unless %w(d w m q).include?(kind)
      raise ArgumentError, "日付は2013年5月1日以降で指定してください" if parsed < Date.new(2013, 5, 1)
      raise ArgumentError, "未来の日付は指定できません" if parsed > Time.now.getlocal("+09:00").to_date
      raise ArgumentError, "週間ランキングの日付は火曜日を指定してください" if kind == "w" && parsed.wday != 2
      raise ArgumentError, "月間・四半期ランキングの日付は1日を指定してください" if %w(m q).include?(kind) && parsed.day != 1
      key = [parsed, kind]
      payload = @mutex.synchronize do
        cached = @cache[key]
        if cached && Time.now - cached[:at] < CACHE_SECONDS
          cached[:data]
        else
          # Retain only the most recent selection, with no disk persistence.
          fresh = load_ranking(parsed, kind)
          @cache.clear
          @cache[key] = {at: Time.now, data: fresh}
          fresh
        end
      end
      ids = registered.each_with_object({}) { |code, result| result[code.to_s.downcase] = true }
      payload.map { |row| row.merge("registered" => !!ids[row["ncode"]]) }
    rescue Date::Error
      raise ArgumentError, "日付が不正です"
    end

    def self.load_ranking(date, kind)
      results = request(RANK_URL, "rtype" => "#{date.strftime('%Y%m%d')}-#{kind}", "out" => "json")
      raise "ランキングを取得できませんでした" unless results.is_a?(Array)
      ranks = results.select { |r| r.is_a?(Hash) && r["ncode"].to_s.match?(/\An\d+[a-z]+\z/i) }.first(LIMIT)
      return [] if ranks.empty?
      codes = ranks.map { |row| row["ncode"].downcase }
      info = request(NOVEL_URL, "ncode" => codes.join("-"), "of" => "n-t-w-s-g-e-nt-ga-l-gl", "lim" => LIMIT, "out" => "json")
      raise "作品情報を取得できませんでした" unless info.is_a?(Array)
      lookup = info.drop(1).each_with_object({}) do |row, acc|
        acc[row["ncode"].to_s.downcase] = row if row.is_a?(Hash) && row["ncode"]
      end
      ranks.map do |row|
        code = row["ncode"].downcase
        detail = lookup[code] || {}
        {"ncode" => code, "rank" => row["rank"], "points" => row["pt"],
         "title" => detail["title"], "writer" => detail["writer"], "story" => detail["story"],
         "genre" => detail["genre"], "end" => detail["end"], "episodes" => detail["general_all_no"],
         "length" => detail["length"], "updated" => detail["general_lastup"]}
      end
    end

    def self.request(url, params)
      uri = URI(url)
      uri.query = URI.encode_www_form(params)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 8, read_timeout: 15) do |http|
        http.get(uri.request_uri, {"User-Agent" => "Narou.rb local ranking prototype", "Accept" => "application/json"})
      end
      raise "APIがHTTP #{response.code}を返しました" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end
  end
end
