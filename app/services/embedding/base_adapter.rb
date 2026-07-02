module Embedding
  class BaseAdapter
    def initialize(provider)
      @provider = provider
    end

    # Returns a flat Array of Floats (the embedding vector)
    def embed(text:)
      raise NotImplementedError, "#{self.class}#embed must be implemented"
    end

    private

    def config
      @provider.config || {}
    end

    def model
      @provider.model
    end
  end
end