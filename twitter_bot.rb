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
# ruby twitter.rb /path/to/sercret_keys.yml /path/to/htmlentities-4.2.0/lib

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
    response = access_token.post(
      'http://twitter.com/statuses/update.json',
      'status'=> tweet
    )
  end
end

# �ե����ɤ򰷤����ܥ��饹
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

  # �ե��������Τ���ּ¹Ի��֤���interval�δ֤Υե����ɡפ���Ф��ޤ���
  # @titles, @links, @publisheds �˥ե��륿��������Ф��줿�ǡ����򥻥åȤ��ޤ���
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
  # GMT�ΤΥե����ɻ��֤����ܤȹ�碌�뤿������Ѥ��ޤ�
  def gmt_mode_japan
    60 * 60 * 9
  end

  # �ե����ɤ�Hpricot�Υ��֥������Ȥˤ��ޤ���
  def open_feed(feed_name = '')
    Hpricot(open(base_url + feed_name))
  end

  def make_elems(feed)
   self
  end

  # �¹Ԥ���ɤΤ��餤���ޤǤΥե����ɤ�������뤫
  def interval
    60 * 60 * 24 * 5
  end
end

# �饤�֥�ܥ�塼�����β��������δ��ۤΥե����ɤ򰷤����饹
class ImpressionOfCompanyIntroduction < Feed
  def base_url
    "http://rec.live-revolution.co.jp"
  end

  def feed
    make_elems(open_feed("/xml/date_feed.xml")).filter
  end

  # Hpricot�Υ��֥������Ȥ���ƥ��󥹥����ѿ�������Ȥ��ƥ��åȤ��ޤ���
  # @all_publishdes�ˤϻ���
  # @all_titles�ˤϥ����ȥ�
  # @all_links�ˤϥ��URL
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