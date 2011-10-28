class UrlGenerator
  def initialize(attachment, options)
    @attachment = attachment
    @options = options
  end

  def for(style_name, options)
    options = handle_url_options(options)
    url = @options.interpolator.interpolate(most_appropriate_url, @attachment, style_name)

    url = url_timestamp(url) if options[:timestamp]
    url = escape_url(url)    if options[:escape]
    url
  end

  private

  def handle_url_options(options)
    timestamp = extract_timestamp(options)
    options = {} if options == true || options == false
    options[:timestamp] = timestamp
    options[:escape] = true if options[:escape].nil?
    options
  end

  def extract_timestamp(options)
    possibilities = [((options == true || options == false) ? options : nil),
      (options.respond_to?(:[]) ? options[:timestamp] : nil),
      @options.use_timestamp]
    possibilities.find{|n| !n.nil? }
  end

  def default_url
    if @options.default_url.respond_to?(:call)
      @options.default_url.call(@attachment)
    else
      @options.default_url
    end
  end

  def most_appropriate_url
    if @attachment.original_filename.nil?
      default_url
    else
      @options.url
    end
  end

  def url_timestamp(url)
    if @attachment.updated_at
      delimiter_char = url.include?("?") ? "&" : "?"
      "#{url}#{delimiter_char}#{@attachment.updated_at.to_s}"
    else
      url
    end
  end

  def escape_url(url)
    url.respond_to?(:escape) ? url.escape : URI.escape(url)
  end
end
