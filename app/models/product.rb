class Product < ActiveRecord::Base
  has_many :reviews, dependent: :destroy

  validates :name, presence: true
  validates :walmart_id, presence: true, uniqueness: true

  def self.add_or_update(url)
    doc = Nokogiri::HTML(open(url))
    reviews_url = doc.at_css("#WMItemSeeAllRevLnk")[:href]
    walmart_id = reviews_url.split("/")[3]
    where(walmart_id: walmart_id).first || add_new(doc, walmart_id, name, reviews_url)
  end

  def to_s
    name
  end

  class << self
    private
    def add_new(doc, walmart_id, name, reviews_url)
      reviews_count = doc.at_css(".review-stats span").text.split(" ")[2].to_i
      name = doc.at_css(".product-name").text
      product = create(name: name, walmart_id: walmart_id)
      (1..reviews_count/20+1).each{ |page| add_reviews(product, reviews_url, page) }
      product
    end

    def add_reviews(product, reviews_url, page)
      url = "https://www.walmart.com#{reviews_url}?limit=20&page=#{page}&sort=submission-asc"
      doc = Nokogiri::HTML(open(url))
      doc.css(".js-customer-review").each do |doc_review|
        title = doc_review.at_css(".customer-review-title").text
        content = doc_review.at_css(".js-customer-review-text").text.gsub("Read more", "")
        stars = doc_review.css(".star-rated").length
        published_at = Date.strptime(doc_review.at_css(".customer-review-date").text, "%m/%d/%Y")
        product.reviews.create(title: title, content: content, stars: stars, published_at: published_at, walmart_id: doc_review["data-content-id"])
      end
    end
  end
end