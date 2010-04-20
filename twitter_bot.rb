#!/usr/bin/env ruby
# coding: utf-8

# LOAD_PATH for htmlentities�饤�֥��
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
### ��TwitterBase���饹�򳰤˽Ф�

# Usage:
# ruby /path/to/twitter_bot.rb /path/to/sercret_keys.yml /path/to/htmlentities-4.2.0/lib /path/to/tweet_history

# Twitter��API�ȤΤ��Ȥ��Ԥ����饹
class TwitterBase
  def initialize
    # config.yml���sercret_keys.yml��load���ޤ���
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
    @response = access_token.post(
      'http://twitter.com/statuses/update.json',
      'status'=> tweet
    )
  end

  def response_success?
    return true if @response.class == Net::HTTPOK

    false
  end
end

# �ե����ɤ򰷤����ܥ��饹
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
  # �ե����ɤ�Hpricot�Υ��֥������Ȥˤ��ޤ���
  def open_feed(feed_name = '')
    Hpricot(open(base_url + feed_name))
  end

  def make_elems(feed)
   self
  end
end

# �饤�֥�ܥ�塼�����β��������δ��ۤΥե����ɤ򰷤����饹
class ImpressionOfCompanyIntroduction < Feed
  def base_url
    "http://rec.live-revolution.co.jp"
  end

  def feed
    make_elems(open_feed("/xml/date_feed.xml"))
  end

  # Hpricot�Υ��֥������Ȥ���ƥ��󥹥����ѿ�������Ȥ��ƥ��åȤ��ޤ���
  # @all_publishdes�ˤϻ���
  # @all_titles�ˤϥ����ȥ�
  # @all_links�ˤϥ��URL
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

    File.open(ARGV[2]) do |file|
      while line = file.gets
       @tweet_histories << line.chomp
      end
    end
  end

  # tweet_history�ե�����˥ݥ������Ƥ�񤭹���
  def write(tweet)
    tweet_history = File.open(ARGV[2], 'a+')
    tweet_history.puts tweet
    tweet_history.close
  end

  # ���˥ݥ��Ȥ������ǧ����
  def past_in_the_tweet?(tweet)
    @tweet_histories.each do |tweet_history|
       return true if tweet_history == tweet
    end

    false
  end

  def maintenance
    tweet_histories = []

    File.open(ARGV[2]) do |file|
      while line = file.gets
       tweet_histories << line.chomp
      end
    end
    
    if tweet_histories.size > stay_history_count
      # �ݻ���������Τߤ�����˼���
      stay_tweet_histories = []
      stay_number = stay_history_count

      tweet_histories.reverse!.each_with_index do |history, index|
        if index <= stay_history_count
          stay_number = stay_number - 1
          stay_tweet_histories << history
        end
      end

      # File Reset
      tweet_history = File.open(ARGV[2], 'w')
      tweet_history.print ''
      tweet_history.close
      
      # �ǿ��Σ����ԤΤ���¸
      tweet_history = File.open(ARGV[2], 'a+')

      stay_tweet_histories.reverse!.each do |history|
        puts history
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


twitter_base  = TwitterBase.new
tweet_history = TweetHistory.new

# ImpressionOfCompanyIntroduction Feed Post
impression_of_company_introduction = ImpressionOfCompanyIntroduction.new
impression_of_company_introduction.feed

impression_of_company_introduction.titles.each_with_index do |title, index|
  tweet = impression_of_company_introduction.header +  impression_of_company_introduction.titles[index] + " - " + impression_of_company_introduction.links[index]

  unless tweet_history.past_in_the_tweet?(tweet)
    twitter_base.post(tweet)

    if twitter_base.response_success?
      tweet_history.write(tweet)
    end
  end
end
# tweet_history�ե���������粽�ɻ�
tweet_history = TweetHistory.new
tweet_history.maintenance
