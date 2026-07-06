class DocumentTemplateChunkingService
  MIN_CHUNK_LENGTH = 50
  MAX_CHUNK_LENGTH = 1000

  def self.call(content, chunk_type: "content")
    new(content, chunk_type: chunk_type).call
  end

  def initialize(content, chunk_type: "content")
    @content    = content.to_s
    @chunk_type = chunk_type
  end

  def call
    case @chunk_type
    when "intent"
      # Intent is always a single chunk — no splitting needed
      [{ chunk_index: 0, content: @content.strip }]
    when "content"
      split_into_paragraphs
    end
  end

  private

  def split_into_paragraphs
    paragraphs = @content
      .split(/\n{2,}/)
      .map(&:strip)
      .reject { |p| p.length < MIN_CHUNK_LENGTH }

    chunks = []
    paragraphs.each do |paragraph|
      if paragraph.length <= MAX_CHUNK_LENGTH
        chunks << paragraph
      else
        chunks.concat(split_by_sentence(paragraph))
      end
    end

    chunks.each_with_index.map do |content, index|
      { chunk_index: index, content: content }
    end
  end

  def split_by_sentence(text)
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