class FeedsController < ApplicationController
  before_action :authenticate_user!

  def index
    @feeds = current_user.feeds
    @new_feed = Feed.new # for the creation form
  end

  def opml
    @feeds = current_user.feeds
    response.headers['Content-Disposition'] = "attachment"
    render layout: false
  end  

  def new_opml
  end

  def ingest_opml
    opml_io = params[:opml]
    feed_list = []
    xml_doc  = Nokogiri::XML(opml_io)
    xml_doc.css("outline").each do |outline|
      feed_url = outline.attribute("xmlUrl")
      feed_list << feed_url.value.to_s unless feed_url.nil?
    end
    flash[:notice] = "Successes: "
    flash[:alert] = "Errors: "
    feed_list.each do |f|
      feed_url = normalize_feed_url(f)
      flashes = add_feed(feed_url)
      flashes[:notices].each do |n|
        flash[:notice] += "#{n}\n"
      end
      flashes[:alerts].each do |a|
        flash[:alert]  += "#{a}\n"
      end
      
    end
    redirect_to :feeds
  end

  def create
    feed_url = normalize_feed_url(params[:feed][:url])
    flashes = add_feed(feed_url)
    flashes[:notices].each do |n|
      flash[:notice] = n
    end
    flashes[:alerts].each do |a|
      flash[:alert] = a 
    end
    redirect_to :feeds
  end

  def destroy
    @feed = Feed.find(params[:id])
    if ( (!@feed.nil?) and (current_user == @feed.user) )
      @feed.destroy!
    else
      flash[:alert] = "You cannot do that"
    end
    redirect_to :feeds
  end

  # fetch content from feeds for reading
  def read
    UpdateFeedJob.perform_later
    @entries = current_user.feed_entries.order(sort_date: :desc).page params[:page]
  end

  def read_feed
    @feed = Feed.find(params[:id])
    @entries=[]
    if ( (!@feed.nil?) and (current_user == @feed.user) )
      @entries = @feed.feed_entries.order(sort_date: :desc).page params[:page]
      UpdateFeedJob.perform_later(@feed)
      render :read
    else
      flash[:alert] = "That does not exist"
      redirect_to :root
    end
  end

  private

  def normalize_feed_url(feed_in)
    ## TODO: rss autodiscovery
    feed_url = feed_in.strip
    unless (feed_url.start_with? "http")
      feed_url = "https://" + feed_url
    end
    return feed_url
  end

  def add_feed(feed_url)
    feed_url_host = URI(feed_url).host
    request_host = URI(request.base_url).host
    matching_feed = Feed.find_by(url: feed_url, user: current_user)
    alerts = []
    notices = []
    if (feed_url_host == request_host)
      alerts << "You cannot subscribe to yourself"
    elsif matching_feed.nil?
      feed = current_user.feeds.create!(url: feed_url)
      UpdateFeedJob.perform_now(feed)
      if feed.feed_invalid?
        alerts << "Error adding #{feed_url} to your feeds"
      else
        notices << "You've added #{feed_url} to your feeds"
      end
    else # feed already exists
      notices << "You are already subscribed to #{feed_url}"
    end
    return {alerts: alerts, notices: notices}
  end

end
