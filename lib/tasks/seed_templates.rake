namespace :templates do
  desc "Seed document templates via AI. Options: limit=20 practice_area=corporate"
  task seed: :environment do
    limit        = (ENV["limit"] || 20).to_i
    practice_area = ENV["practice_area"].presence

    puts "Starting template seed: limit=#{limit}, practice_area=#{practice_area || 'all'}"

    result = DocumentTemplateSeedService.call(
      limit:         limit,
      practice_area: practice_area
    )

    puts "Done. Enqueued: #{result[:enqueued]}, Skipped: #{result[:skipped]}, Failed: #{result[:failed]}"
  end
end