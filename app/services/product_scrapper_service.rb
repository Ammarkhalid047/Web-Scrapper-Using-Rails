require 'mechanize'
require 'csv'
require 'httparty'
require 'wordpress_client'

class ProductScrapperService
  def initialize(base_url)
    @base_url = base_url
    @agent = Mechanize.new
    @visited_urls = []
    @products = []
  end

  def crawl
    start_crawl(@base_url)
    @products
  end

  private

  def start_crawl(url)
    return if @visited_urls.include?(url)

    page = @agent.get(url)
    page.search('.product-layout').each do |product_element|
        name = product_element.at('.caption .name').text.strip
        description = product_element.at('.caption .description').text.strip
        image_element = product_element.at('.image img')
        @products << { name: name, image_url: image_element['src'], description: description }
    end

    @visited_urls << url

    next_page = find_next_page_url(page)
    start_crawl(next_page) unless next_page.nil?
    write_to_csv(@products)
  end

  def find_next_page_url(page)
    next_page_link = page.at('css_selector_for_next_page')
    return nil if next_page_link.nil?

    URI.join(@base_url, next_page_link['href']).to_s
  end

  def write_to_csv(products)
    csv_file_path = Rails.root.join('public', 'csv', 'products.csv')
    FileUtils.mkdir_p(File.dirname(csv_file_path))
    
    CSV.open(csv_file_path, 'w') do |csv|
      csv << ['Name', 'Description', 'Image URL', 'Category']
      products.each do |product|
        csv << [product[:name], product[:description], product[:image_url], ]
        upload_media_to_wordpress(product[:image_url], product[:name])
        # upload_image_to_wordpress(image_url, wordpress_username, wordpress_password)
      end
    end
  end

  def upload_media_to_wordpress(url, title)
    begin
      client = WordpressClient.new(
        url: 'https://madhicorporation.com/surgical',
        username: 'madhi',
        password: 'EU6@6%tIEm'
      )
      media = WordpressClient::Media.new(link: url, title_html: title)
      media.upload!(client)
      { media_id: media.id }
    rescue WordpressClient::Error => e
      { error: e.message }
    end
  end


  def upload_image_to_wordpress(url, username, password)
    # Authenticate with WordPress REST API
    headers = {
        'Authorization' => 'Basic ' + Base64.strict_encode64("#{username}:#{password}"),
        'Content-Disposition' => "attachment; filename=\"#{File.basename(url)}\""
      }
    debugger
    # Make a POST request to upload the image
    response = HTTParty.post(
      'https://madhicorporation.com/surgical/wp-json/wp/v2/media',
      headers: headers,
      body: {
        source_url: url
      }
    )
    debugger
    # Handle the response
    if response.success?
      data = JSON.parse(response.body)
      debugger
      # The media ID of the uploaded image can be accessed using data['id']
      puts "Image uploaded successfully. Media ID: #{data['id']}"
    else
      puts "Image upload failed. Error: #{response.code} - #{response.message}"
    end
  end
end
