require File.expand_path('spec_helper', File.dirname(__FILE__))

describe Sunspot::Search do
  it 'should allow access to the data accessor' do
    stub_results(posts = Post.new)
    search = session.search Post do
      data_accessor_for(Post).custom_title = 'custom title'
    end
    search.results.first.title.should == 'custom title'
  end
  
  it 'should re-execute search' do
    post_1, post_2 = Post.new, Post.new
    
    stub_results(post_1)
    search = session.search Post
    search.results.should == [post_1]
    
    stub_results(post_2)
    search.execute!
    search.results.should == [post_2]
  end

  describe "RetrySearch" do

    it 'should re-execute search on partialResults' do
      post_1 = Post.new

      stub_partial_results(*[{'instance' => post_1}])
      search = session.new_retry_search Post
      search.should_receive(:execute).exactly(4).times.and_call_original
      search.execute
      search.results.should == [post_1]
    end

    it 'should not re-execute search on partialResults' do
      post_1 = Post.new

      stub_results(post_1)
      search = session.new_retry_search Post
      search.should_receive(:execute).exactly(1).times.and_call_original
      search.execute
      search.results.should == [post_1]
    end

  end
end
