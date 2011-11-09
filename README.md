# Sunspot

[![Build Status](http://travis-ci.org/sunspot/sunspot.png)](http://travis-ci.org/sunspot/sunspot)

Sunspot is a Ruby library for expressive, powerful interaction with the Solr
search engine. Sunspot is built on top of the RSolr library, which
provides a low-level interface for Solr interaction; Sunspot provides a simple,
intuitive, expressive DSL backed by powerful features for indexing objects and
searching for them.

Sunspot is designed to be easily plugged in to any ORM, or even non-database-backed
objects such as the filesystem.

## Quickstart with Rails 3

Add to Gemfile:

```ruby
gem 'sunspot_rails'
gem 'sunspot_solr' # optional pre-packaged Solr distribution for use in development
```

Bundle it!

```bash
bundle install
```

Generate a default configuration file:

```bash
rails generate sunspot_rails:install
```

If `sunspot_solr` was installed, start the packaged Solr distribution
with:

```bash
bundle exec rake sunspot:solr:start # or sunspot:solr:run to start in foreground
```

## Setting Up Objects

Add a `searchable` block to the objects you wish to index.

```ruby
class Post < ActiveRecord::Base
  searchable do
    text :title, :body
    text :comments do
      comments.map { |comment| comment.body }
    end

    boolean :featured
    integer :blog_id
    integer :author_id
    integer :category_ids, :multiple => true
    double  :average_rating
    time    :published_at
    time    :expired_at

    string  :sort_title do
      title.downcase.gsub(/^(an?|the)/, '')
    end
  end
end
```

`text` fields will be full-text searchable. Other fields (e.g.,
`integer` and `string`) can be used to scope queries.

## Searching Objects

```ruby
Post.search do
  fulltext 'best pizza'

  with :blog_id, 1
  with(:published_at).less_than Time.now
  order_by :published_at, :desc
  paginate :page => 2, :per_page => 15
  facet :category_ids, :author_id
end
```

## Search In Depth

Given an object `Post` setup in earlier steps ...

### Full Text

```ruby
# All posts with a `text` field (:title, :body, or :comments) containing 'pizza'
Post.search { fulltext 'pizza' }

# Posts with pizza, scored higher if pizza appears in the title
Post.search do
  fulltext 'pizza' do
    boost_fields :title => 2.0
  end
end

# Posts with pizza, scored higher if featured
Post.search do
  fulltext 'pizza' do
    boost(2.0) { with(:featured, true) }
  end
end

# Posts with pizza *only* in the title
Post.search do
  fulltext 'pizza' do
    fields(:title)
  end
end

# Posts with pizza in the title (boosted) or in the body (not boosted)
Post.search do
  fulltext 'pizza' do
    fields(:body, :title => 2.0)
  end
end
```

### Scoping (Scalar Fields)

Fields not defined as `text` (e.g., `integer`, `boolean`, `time`,
etc...) can be used to scope (restrict) queries before full-text
matching is performed.

#### Positive Restrictions

```ruby
# Posts with a blog_id of 1
Post.search do
  with(:blog_id, 1)
end

# Posts with an average rating between 3.0 and 5.0
Post.search do
  with(:average_rating, 3.0..5.0)
end

# Posts with a category of 1, 3, or 5
Post.search do
  with(:category_ids, [1, 3, 5])
end

# Posts published since a week ago
Post.search do
  with(:published_at).greater_than(1.week.ago)
end
```

#### Negative Restrictions

```ruby
# Posts not in category 1 or 3
Post.search do
  without(:category_ids, [1, 3])
end

# All examples in "positive" also work negated using `without`
```

#### Disjunctions and Conjunctions

```ruby
# Posts that do not have an expired time or have not yet expired
Post.search do
  any_of do
    with(:expired_at).greater_than(Time.now)
    with(:expired_at, nil)
  end
end
```

```ruby
# Posts with blog_id 1 and author_id 2
Post.search do
  all_of do
    with(:blog_id, 1)
    with(:author_id, 2)
  end
end
```

Disjunctions and conjunctions may be nested

```ruby
Post.search do
  any_of do
    with(:blog_id, 1)
    all_of do
      with(:blog_id, 2)
      with(:category_ids, 3)
    end
  end
end
```

#### Combined with Full-Text

Scopes/restrictions can be combined with full-text searching. The
scope/restriction pares down the objects that are searched for the
full-text term.

```ruby
# Posts with blog_id 1 and 'pizza' in the title
Post.search do
  with(:blog_id, 1)
  fulltext("pizza")
end
```

### Pagination

TODO

### Faceting

Faceting is a feature of Solr that determines the number of documents
that match a given search *and* an additional criterion. This allows you
to build powerful drill-down interfaces for search.

Each facet returns zero or more rows, each of which represents a
particular criterion conjoined with the actual query being performed.
For **field facets**, each row represents a particular value for a given
field. For **query facets**, each row represents an arbitrary scope; the
facet itself is just a means of logically grouping the scopes.

#### Field Facets

```ruby
# Posts that match 'pizza' returning counts for each :author_id
search = Post.search do
  fulltext "pizza"
  facet :author_id
end

search.facet(:author_id).rows.each do |facet|
  puts "Author #{facet.value} has #{facet.count} pizza posts!"
end
```

#### Query Facets

```ruby
# Posts faceted by ranges of average ratings
Post.search do
  facet(:average_rating) do
    row(1.0..2.0) do
      with(:average_rating, 1.0..2.0)
    end
    row(2.0..3.0) do
      with(:average_rating, 2.0..3.0)
    end
    row(3.0..4.0) do
      with(:average_rating, 3.0..4.0)
    end
    row(4.0..5.0) do
      with(:average_rating, 4.0..5.0)
    end
  end
end

# e.g.,
# Number of posts with rating withing 1.0..2.0: 2
# Number of posts with rating withing 2.0..3.0: 1
search.facet(:average_rating).rows.each do |facet|
  puts "Number of posts with rating withing #{facet.value}: #{facet.count}"
end
```

### Ordering

By default, Sunspot orders results by "score": the Solr-determined
relevant score. Sorting can be customized with the `order_by` method:

```ruby
# Order by average rating, descending
Post.search do
  fulltext("pizza")
  order_by(:average_rating, :desc)
end

# Order by relevancy score and in the case of a tie, average rating
Post.search do
  fulltext("pizza")

  order_by(:score, :desc)
  order_by(:average_rating, :desc)
end

# Randomized ordering
Post.search do
  fulltext("pizza")
  order_by(:random)
end
```

### Geospatial

TODO

### Highlighting

TODO

## Indexing In Depth

TODO

## Reindexing Objects

If you are using Rails, objects are automatically indexed to Solr as a
part of the `save` callbacks.

If you make a change to the object's "schema" (code in the `searchable` block),
you must reindex all objects so the changes are reflected in Solr:

```bash
bundle exec rake sunspot:solr:reindex

# or, to be specific to a certain model with a certain batch size:
bundle exec rake sunspot:solr:reindex[500,Post] # some shells will require escaping [ with \[ and ] with \]
```

## Use Without Rails

TODO

## Tutorials and Articles

* [Full Text Searching with Solr and Sunspot](http://collectiveidea.com/blog/archives/2011/03/08/full-text-searching-with-solr-and-sunspot/) (Collective Idea)
* [Full-text search in Rails with Sunspot](http://tech.favoritemedium.com/2010/01/full-text-search-in-rails-with-sunspot.html) (Tropical Software Observations)
* [Sunspot Full-text Search for Rails/Ruby](http://therailworld.com/posts/23-Sunspot-Full-text-Search-for-Rails-Ruby) (The Rail World)
* [A Few Sunspot Tips](http://blog.trydionel.com/2009/11/19/a-few-sunspot-tips/) (spiral_code)
* [Sunspot: A Solr-Powered Search Engine for Ruby](http://www.linux-mag.com/id/7341) (Linux Magazine)
* [Sunspot Showed Me the Light](http://bennyfreshness.com/2010/05/sunspot-helped-me-see-the-light/) (ben koonse)
* [RubyGems.org — A case study in upgrading to full-text search](http://blog.websolr.com/post/3505903537/rubygems-search-upgrade-1) (Websolr)
* [How to Implement Spatial Search with Sunspot and Solr](http://codequest.eu/articles/how-to-implement-spatial-search-with-sunspot-and-solr) (Code Quest)
* [Sunspot 1.2 with Spatial Solr Plugin 2.0](http://joelmats.wordpress.com/2011/02/23/getting-sunspot-1-2-with-spatial-solr-plugin-2-0-to-work/) (joelmats)
* [rails3 + heroku + sunspot : madness](http://anhaminha.tumblr.com/post/632682537/rails3-heroku-sunspot-madness) (anhaminha)
* [How to get full text search working with Sunspot](http://cookbook.hobocentral.net/recipes/57-how-to-get-full-text-search) (Hobo Cookbook)
* [Full text search with Sunspot in Rails](http://hemju.com/2011/01/04/full-text-search-with-sunspot-in-rail/) (hemju)
* [Using Sunspot for Free-Text Search with Redis](http://masonoise.wordpress.com/2010/02/06/using-sunspot-for-free-text-search-with-redis/) (While I Pondered...)
* [Fuzzy searching in SOLR with Sunspot](http://www.pipetodevnull.com/past/2010/8/5/fuzzy_searching_in_solr_with_sunspot/) (pipe :to => /dev/null)
* [Default scope with Sunspot](http://www.cloudspace.com/blog/2010/01/15/default-scope-with-sunspot/) (Cloudspace)
* [Index External Models with Sunspot/Solr](http://www.medihack.org/2011/03/19/index-external-models-with-sunspotsolr/) (Medihack)
* [Chef recipe for Sunspot in production](http://gist.github.com/336403)
* [Testing with Sunspot and Cucumber](http://collectiveidea.com/blog/archives/2011/05/25/testing-with-sunspot-and-cucumber/) (Collective Idea)
* [Cucumber and Sunspot](http://opensoul.org/2010/4/7/cucumber-and-sunspot) (opensoul.org)
* [Testing Sunspot with Cucumber](http://blog.trydionel.com/2010/02/06/testing-sunspot-with-cucumber/) (spiral_code)
* [Running cucumber features with sunspot_rails](http://blog.kabisa.nl/2010/02/03/running-cucumber-features-with-sunspot_rails) (Kabisa Blog)
* [Testing Sunspot with Test::Unit](http://timcowlishaw.co.uk/post/3179661158/testing-sunspot-with-test-unit) (Type Slowly)
* [How To Use Twitter Lists to Determine Influence](http://www.untitledstartup.com/2010/01/how-to-use-twitter-lists-to-determine-influence/) (Untitled Startup)
* [Sunspot Quickstart](http://wiki.websolr.com/index.php/Sunspot_Quickstart) (WebSolr)
* [Solr, and Sunspot](http://www.kuahyeow.com/2009/08/solr-and-sunspot.html) (YT!)
* [The Saga of the Switch](http://mrb.github.com/2010/04/08/the-saga-of-the-switch.html) (mrb -- includes comparison of Sunspot and Ultrasphinx)

## License

Sunspot is distributed under the MIT License, copyright (c) 2008-2009 Mat Brown
