#!/usr/bin/env ruby
# coding: utf-8

# LOAD_PATH for htmlentitiesライブラリ
# htmlentities see: http://d.hatena.ne.jp/japanrock_pg/20100316/1268732145
$LOAD_PATH.unshift(ARGV[1])

require 'rubygems'
require 'oauth'
require 'json'
require 'hpricot'
require 'open-uri'
require 'yaml'
require 'parsedate'
require "kconv"
require 'htmlentities'


### TODO:
### ・TwitterBaseクラスを外に出す

# Usage:
# ruby twitter.rb /path/to/sercret_keys.yml /path/to/htmlentities-4.2.0/lib

# TwitterのAPIとのやりとりを行うクラス
class TwitterBase
  def initialize
    # config.yml内のsercret_keys.ymlをloadします。
    @secret_keys = YAML.load_file(ARGV[0] || 'sercret_keys.yml')
  end
  
  def consumer_key
    @secret_keys["ConsumerKey"]
  end

  def consumer_secret
    @secret_keys["ConsumerSecret"]
  end

  def access_token_key
    @secret_keys["AccessToken"]
  end

  def access_token_secret
    @secret_keys["AccessTokenSecret"]
  end

  def consumer
    @consumer = OAuth::Consumer.new(
      consumer_key,
      consumer_secret,
      :site => 'http://twitter.com'
    )
  end

  def access_token
    consumer
    access_token = OAuth::AccessToken.new(
      @consumer,
      access_token_key,
      access_token_secret
    )
  end

  def post(tweet=nil)
    response = access_token.post(
      'http://twitter.com/statuses/update.json',
      'status'=> tweet
    )
  end
end

# フィードを扱う基本クラス
class Feed
  attr_reader :publisheds
  attr_reader :titles
  attr_reader :links
  
  def initialize
    @all_publisheds = []
    @all_titles     = []
    @all_links      = []
    @all_descriptions = []
    @publisheds = []
    @titles     = []
    @links      = []
  end

  # フィード全体から「実行時間からintervalの間のフィード」を抽出します。
  # @titles, @links, @publisheds にフィルターから抽出されたデータをセットします。
  def filter
    return self if @all_publisheds.empty?

    @all_publisheds.each_with_index do|published, index|
      published = ParseDate::parsedate(published)[0..-3].join(',').split(/,/)

      if Time.now < Time.local(published[0].to_i, published[1].to_i, published[2].to_i, published[3].to_i, published[4].to_i, published[5].to_i) + gmt_mode_japan + interval
        @publisheds << published.join(',')
        @titles << Kconv.toutf8(@all_titles[index])
        @links << @all_links[index]
      end
    end
  end

  def header
    ''
  end

  private
  # GMTののフィード時間を日本と合わせるために利用します
  def gmt_mode_japan
    60 * 60 * 9
  end

  # フィードをHpricotのオブジェクトにします。
  def open_feed(feed_name = '')
    Hpricot(open(base_url + feed_name))
  end

  def make_elems(feed)
   self
  end

  # 実行からどのくらい前までのフィードを取得するか
  def interval
    60 * 60 * 24 * 5
  end
end

# ライブレボリューションの会社説明会の感想のフィードを扱うクラス
class ImpressionOfCompanyIntroduction < Feed
  def base_url
    "http://rec.live-revolution.co.jp"
  end

  def feed
    make_elems(open_feed("/xml/date_feed.xml")).filter
  end

  # Hpricotのオブジェクトから各インスタンス変数に配列としてセットします。
  # @all_publishdesには時間
  # @all_titlesにはタイトル
  # @all_linksにはリンクURL
  def make_elems(feed)
    if feed.class == Hpricot::Doc
      (feed/'entry'/'published').each do |published|
        @all_publisheds << published.inner_html
      end

      (feed/'entry'/'title').each do |title|
        @all_titles << HTMLEntities.new.decode(title.inner_html)
      end
    
      (feed/'entry'/'link').each do |link|
        @all_links << link.attributes['href']
      end   
    end

    self
  end

  def header
    ''
  end

  private
  def gmt_mode_japan
    0 
  end
end

twitter_base     = TwitterBase.new

# ImpressionOfCompanyIntroduction Feed Post
impression_of_company_introduction = ImpressionOfCompanyIntroduction.new
impression_of_company_introduction.feed
impression_of_company_introduction.titles.each_with_index do |title, index|
  twitter_base.post(impression_of_company_introduction.header +  impression_of_company_introduction.titles[index] + " - " + impression_of_company_introduction.links[index])
end
