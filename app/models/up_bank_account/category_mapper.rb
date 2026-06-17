class UpBankAccount::CategoryMapper
  # Up Bank's official top-level category groups: slug => [name, color, lucide_icon].
  PARENT_META = {
    "good-life" => [ "Good Life", "#c44fe9", "drama" ],
    "home"      => [ "Home",      "#e99537", "home" ],
    "personal"  => [ "Personal",  "#4da568", "users" ],
    "transport" => [ "Transport", "#6471eb", "bus" ],
  }.freeze

  # Up Bank's official child categories (the ones transactions reference via
  # relationships.category): slug => [name, parent_slug, lucide_icon].
  CHILDREN = {
    "adult"                             => [ "Adult", "good-life", "drama" ],
    "booze"                             => [ "Booze", "good-life", "wine" ],
    "events-and-gigs"                   => [ "Events & Gigs", "good-life", "ticket" ],
    "games-and-software"                => [ "Apps, Games & Software", "good-life", "gamepad-2" ],
    "hobbies"                           => [ "Hobbies", "good-life", "palette" ],
    "holidays-and-travel"               => [ "Holidays & Travel", "good-life", "plane" ],
    "lottery-and-gambling"              => [ "Lottery & Gambling", "good-life", "ticket" ],
    "pubs-and-bars"                     => [ "Pubs & Bars", "good-life", "wine" ],
    "restaurants-and-cafes"             => [ "Restaurants & Cafes", "good-life", "utensils" ],
    "takeaway"                          => [ "Takeaway", "good-life", "shopping-bag" ],
    "tobacco-and-vaping"                => [ "Tobacco & Vaping", "good-life", "cigarette" ],
    "tv-and-music"                      => [ "TV, Music & Streaming", "good-life", "tv" ],
    "groceries"                         => [ "Groceries", "home", "shopping-bag" ],
    "home-insurance-and-rates"          => [ "Rates & Insurance", "home", "shield" ],
    "home-maintenance-and-improvements" => [ "Maintenance & Improvements", "home", "hammer" ],
    "homeware-and-appliances"           => [ "Homeware & Appliances", "home", "lamp" ],
    "internet"                          => [ "Internet", "home", "wifi" ],
    "pets"                              => [ "Pets", "home", "paw-print" ],
    "rent-and-mortgage"                 => [ "Rent & Mortgage", "home", "home" ],
    "utilities"                         => [ "Utilities", "home", "lightbulb" ],
    "clothing-and-accessories"          => [ "Clothing & Accessories", "personal", "shirt" ],
    "education-and-student-loans"       => [ "Education & Student Loans", "personal", "graduation-cap" ],
    "family"                            => [ "Children & Family", "personal", "baby" ],
    "fitness-and-wellbeing"             => [ "Fitness & Wellbeing", "personal", "dumbbell" ],
    "gifts-and-charity"                 => [ "Gifts & Charity", "personal", "gift" ],
    "hair-and-beauty"                   => [ "Hair & Beauty", "personal", "scissors" ],
    "health-and-medical"                => [ "Health & Medical", "personal", "stethoscope" ],
    "investments"                       => [ "Investments", "personal", "trending-up" ],
    "life-admin"                        => [ "Life Admin", "personal", "briefcase" ],
    "mobile-phone"                      => [ "Mobile Phone", "personal", "smartphone" ],
    "news-magazines-and-books"          => [ "News, Magazines & Books", "personal", "newspaper" ],
    "technology"                        => [ "Technology", "personal", "smartphone" ],
    "car-insurance-and-maintenance"     => [ "Car Insurance, Rego & Maintenance", "transport", "wrench" ],
    "car-repayments"                    => [ "Repayments", "transport", "credit-card" ],
    "cycling"                           => [ "Cycling", "transport", "bike" ],
    "fuel"                              => [ "Fuel", "transport", "fuel" ],
    "parking"                           => [ "Parking", "transport", "circle-parking" ],
    "public-transport"                  => [ "Public Transport", "transport", "bus" ],
    "taxis-and-share-cars"              => [ "Taxis & Share Cars", "transport", "car" ],
    "toll-roads"                        => [ "Tolls", "transport", "car" ],
  }.freeze

  def initialize(family)
    @family = family
  end

  # Ensures Up Bank's official taxonomy exists for the family (idempotent) and
  # returns a hash of { up_category_slug => SURE category id } for the child
  # categories that transactions reference. Parents are created/reused too so
  # the categories nest correctly in the UI. Memoized via the caller.
  def slug_to_category_id
    by_name = @family.categories.pluck(:name, :id).to_h

    parent_ids = {}
    PARENT_META.each do |slug, (name, color, icon)|
      parent_ids[slug] = by_name[name] ||
        @family.categories.create!(name: name, color: color, lucide_icon: icon).id
    end

    map = {}
    CHILDREN.each do |slug, (name, parent_slug, icon)|
      id = by_name[name]
      unless id
        parent_color = PARENT_META[parent_slug][1]
        id = @family.categories.create!(
          name: name, parent_id: parent_ids[parent_slug],
          color: parent_color, lucide_icon: icon
        ).id
      end
      map[slug] = id
    end
    map
  end
end
