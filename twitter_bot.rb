#!/usr/bin/env ruby
# coding: utf-8

# LOAD_PATH for htmlentitiesライブラリ
# htmlentities see: http://d.hatena.ne.jp/japanrock_pg/20100316/1268732145
$LOAD_PATH.unshift(File.dirname(__FILE__) + '/htmlentities-4.2.0/lib/')

require 'rubygems'
require 'oauth'
require 'json'
require 'hpricot'
require 'open-uri'
require 'yaml'
require 'parsedate'
require "kconv"
require 'htmlentities'
require File.dirname(__FILE__) + '/twitter_oauth'
require File.dirname(__FILE__) + '/shorten_url'

# Usage:
#  1. このファイルやディレクトリを同じディレクトリに配置します。
#   * twitter_oauth.rb
#    * http://github.com/japanrock/TwitterTools/blob/master/twitter_oauth.rb
#   * sercret_key.yml
#    * http://github.com/japanrock/TwitterTools/blob/master/secret_keys.yml.example
#   * htmlentities-4.2.0/ ディレクトリ
#    * http://github.com/japanrock/TwitterLR_Sess_I_Day/tree/master/htmlentities-4.2.0/
#   * shorten_url.rb
#    * http://github.com/japanrock/TwitterTools/blob/master/shorten_url.rb
#   * bit_ly_api_key.yml
#    * http://github.com/japanrock/TwitterTools/blob/master/bit_ly_api_key.yml
#  2. このファイルを実行します。
#   ruby twitter_bot.rb

# フィードを扱う基本クラス
class Feed
  attr_reader :publisheds
  attr_reader :titles
  attr_reader :links
  
  def initialize
    @publisheds = []
    @titles     = []
    @links      = []
  end

  def header
    ''
  end

  private
  # フィードをHpricotのオブジェクトにします。
  def open_feed(feed_name = '')
    Hpricot(open(base_url + feed_name))
  end

  def make_elems(feed)
   self
  end
end

# ライブレボリューションの会社説明会の感想のフィードを扱うクラス
class LrSessIDay < Feed
  def base_url
    "http://rec.live-revolution.co.jp"
  end

  def feed
    make_elems(open_feed("/xml/date_feed.xml"))
  end

  # Hpricotのオブジェクトから各インスタンス変数に配列としてセットします。
  # @all_publishdesには時間
  # @all_titlesにはタイトル
  # @all_linksにはリンクURL
  def make_elems(feed)
    if feed.class == Hpricot::Doc
      (feed/'entry'/'published').each do |published|
        @publisheds << published.inner_html
      end

      (feed/'entry'/'title').each do |title|
        @titles << HTMLEntities.new.decode(title.inner_html)
      end
    
      (feed/'entry'/'link').each do |link|
        @links << link.attributes['href']
      end   
    end

    self
  end

  def header
    ''
  end
end

class TweetHistory
  def initialize
    @tweet_histories = []

    File.open(File.dirname(__FILE__) + '/tweet_history') do |file|
      while line = file.gets
       @tweet_histories << line.chomp
      end
    end
  end

  # tweet_historyファイルにポスト内容を書き込む
  def write(tweet)
    tweet_history = File.open(File.dirname(__FILE__) + '/tweet_history', 'a+')
    tweet_history.puts tweet
    tweet_history.close
  end

  # 過去にポストしかを確認する
  def past_in_the_tweet?(tweet)
    @tweet_histories.each do |tweet_history|
       return true if tweet_history == tweet
    end

    false
  end

  def maintenance
    tweet_histories = []

    File.open(File.dirname(__FILE__) + '/tweet_history') do |file|
      while line = file.gets
       tweet_histories << line.chomp
      end
    end
    
    if tweet_histories.size > stay_history_count
      # 保持する履歴のみを配列に取得
      stay_tweet_histories = []
      stay_number = stay_history_count

      tweet_histories.reverse!.each_with_index do |history, index|
        if index <= stay_history_count
          stay_number = stay_number - 1
          stay_tweet_histories << history
        end
      end

      # File Reset
      tweet_history = File.open(File.dirname(__FILE__) + '/tweet_history', 'w')
      tweet_history.print ''
      tweet_history.close
      
      # 最新の２０行のみ保存
      tweet_history = File.open(File.dirname(__FILE__) + '/tweet_history', 'a+')

      stay_tweet_histories.reverse!.each do |history|
        tweet_history.puts history
      end

      tweet_history.close
    end
  end

  private

  def stay_history_count
    30
  end
end


twitter_oauth = TwitterOauth.new
tweet_history = TweetHistory.new
shorten_url   = ShortenURL.new

# LrSessIDay Feed Post
lr_sess_i_day = LrSessIDay.new
lr_sess_i_day.feed

lr_sess_i_day.titles.each_with_index do |title, index|
  tweet = lr_sess_i_day.header +  lr_sess_i_day.titles[index] + " - " + lr_sess_i_day.links[index]

  unless tweet_history.past_in_the_tweet?(tweet)
    # URL短縮
    shorten_url.get_short_url(lr_sess_i_day.links[index])
    short_url = shorten_url.short_url

    tweet_short_url_version = lr_sess_i_day.header +  lr_sess_i_day.titles[index] + " - " + short_url

    twitter_oauth.post(tweet_short_url_version)

    if twitter_oauth.response_success?
      tweet_history.write(tweet)
    end
  end
end

# tweet_historyファイルの肥大化防止
tweet_history = TweetHistory.new
tweet_history.maintenance
