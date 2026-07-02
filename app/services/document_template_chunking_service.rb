class DocumentTemplateChunkingService
  MIN_CHUNK_LENGTH = 50   # skip chunks too short to be meaningful
  MAX_CHUNK_LENGTH = 1000 # keep chunks within embedding model token limits

  def self.call(content_raw)
    new(content_raw).call
  end

  def initialize(content_raw)
    @content_raw = content_raw.to_s
  end

  def call
    paragraphs = @content_raw
      .split(/\n{2,}/)       # split on blank lines (paragraph breaks)
      .map(&:strip)
      .reject { |p| p.length < MIN_CHUNK_LENGTH }

    chunks = []
    paragraphs.each do |paragraph|
      if paragraph.length <= MAX_CHUNK_LENGTH
        chunks << paragraph
      else
        # Split oversized paragraphs by sentence
        chunks.concat(split_by_sentence(paragraph))
      end
    end

    chunks.each_with_index.map do |content, index|
      { chunk_index: index, content: content }
    end
  end

  private

  def split_by_sentence(text)
    # Naive sentence splitter — sufficient for legal English
    text.split(/(?<=[.?!])\s+/)
        .each_with_object([]) do |sentence, groups|
          if groups.empty? || (groups.last + " " + sentence).length > MAX_CHUNK_LENGTH
            groups << sentence
          else
            groups[-1] += " #{sentence}"
          end
        end
  end
end