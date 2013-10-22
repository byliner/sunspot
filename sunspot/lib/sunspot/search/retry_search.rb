module Sunspot
  # 
  # This class encapsulates the results of a Solr Retry search. see Sunspot.retry_search and
  # Sunspot.new_retry_search methods.
  #
  module Search
    class RetrySearch < AbstractSearch

      def execute(retry_count = 3)
        reset
        params = @query.to_params
        @solr_result = @connection.post "#{request_handler}", :data => params
        if @solr_result["responseHeader"].nil? || 
            @solr_result["responseHeader"]["partialResults"].nil? || 
            retry_count < 1
          self
        else
          execute(retry_count - 1)
        end
      end

      def request_handler
        super || :select
      end
  
      private
  
      def dsl
        DSL::Search.new(self, @setup)
      end

    end
  end
end
