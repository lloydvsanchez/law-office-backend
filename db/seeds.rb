# ==============================================================================
# LLM Providers
# Seeded only if the corresponding API key environment variable is present.
# Idempotent — safe to run multiple times via find_or_create_by!
# ==============================================================================

puts "==> Seeding LLM Providers..."

llm_providers = [
  {
    name:              "OpenAI",
    adapter_key:       "openai",
    model:             "gpt-4o",
    priority:          1,
    failure_threshold: 3,
    api_key_env:       "OPENAI_API_KEY"
  },
  {
    name:              "Anthropic",
    adapter_key:       "anthropic",
    model:             "claude-sonnet-4-6",
    priority:          2,
    failure_threshold: 3,
    api_key_env:       "ANTHROPIC_API_KEY"
  },
  {
    name:              "Gemini",
    adapter_key:       "gemini",
    model:             "gemini-2.0-flash",
    priority:          3,
    failure_threshold: 3,
    api_key_env:       "GEMINI_API_KEY"
  },
  {
    name:              "Groq",
    adapter_key:       "groq",
    model:             "llama-3.3-70b-versatile",
    priority:          4,
    failure_threshold: 3,
    api_key_env:       "GROQ_API_KEY"
  },
  {
    name:              "Mistral",
    adapter_key:       "mistral",
    model:             "mistral-large-latest",
    priority:          5,
    failure_threshold: 3,
    api_key_env:       "MISTRAL_API_KEY"
  }
]

llm_providers.each do |attrs|
  api_key = ENV[attrs[:api_key_env]].presence

  unless api_key
    puts "  Skipping LlmProvider '#{attrs[:name]}' — #{attrs[:api_key_env]} not set"
    next
  end

  provider = LlmProvider.find_or_create_by!(adapter_key: attrs[:adapter_key]) do |p|
    p.name              = attrs[:name]
    p.model             = attrs[:model]
    p.priority          = attrs[:priority]
    p.failure_threshold = attrs[:failure_threshold]
    p.is_enabled        = true
    p.status            = "healthy"
    p.failure_count     = 0
    p.config            = { "api_key" => api_key }
  end

  puts "  #{provider.previously_new_record? ? "Created" : "Found"} LlmProvider '#{provider.name}'"
end

# ==============================================================================
# Embedding Providers
# Ollama — always seeded locally, disabled in production
# HuggingFace — seeded only if HUGGINGFACE_API_KEY is present
# Idempotent — safe to run multiple times via find_or_create_by!
# ==============================================================================

puts "==> Seeding Embedding Providers..."

embedding_providers = [
  {
    name:              "Ollama",
    adapter_key:       "ollama",
    model:             ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text"),
    priority:          Rails.env.production? ? 2 : 1,
    failure_threshold: 3,
    api_key_env:       nil,
    is_enabled:        !Rails.env.production?,
    config:            { "base_url" => ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434") }
  },
  {
    name:              "HuggingFace",
    adapter_key:       "hugging_face",
    model:             "sentence-transformers/all-mpnet-base-v2",
    priority:          Rails.env.production? ? 1 : 2,
    failure_threshold: 3,
    api_key_env:       "HUGGINGFACE_API_KEY",
    is_enabled:        true,
    config:            nil
  }
]

embedding_providers.each do |attrs|
  if attrs[:api_key_env].present?
    api_key = ENV[attrs[:api_key_env]].presence

    unless api_key
      puts "  Skipping EmbeddingProvider '#{attrs[:name]}' — #{attrs[:api_key_env]} not set"
      next
    end

    config = { "api_key" => api_key }
  else
    config = attrs[:config]
  end

  provider = EmbeddingProvider.find_or_create_by!(adapter_key: attrs[:adapter_key]) do |p|
    p.name              = attrs[:name]
    p.model             = attrs[:model]
    p.priority          = attrs[:priority]
    p.failure_threshold = attrs[:failure_threshold]
    p.is_enabled        = attrs[:is_enabled]
    p.status            = "healthy"
    p.failure_count     = 0
    p.config            = config
  end

  puts "  #{provider.previously_new_record? ? "Created" : "Found"} EmbeddingProvider '#{provider.name}'"
end

# ==============================================================================
# Philippine Laws
# ==============================================================================

puts "==> Seeding Philippine Laws..."

laws = [
  { abbreviation: "BP 22",       pattern: '\bBP\s*22\b',        full_name: "Batas Pambansa Bilang 22",                       description: "the Bouncing Checks Law, which penalizes the making or drawing of checks without sufficient funds" },
  { abbreviation: "BP 68",       pattern: '\bBP\s*68\b',        full_name: "Batas Pambansa Bilang 68",                       description: "the Corporation Code of the Philippines" },
  { abbreviation: "BP 881",      pattern: '\bBP\s*881\b',       full_name: "Batas Pambansa Bilang 881",                      description: "the Omnibus Election Code" },
  { abbreviation: "RA 3019",     pattern: '\bRA\s*3019\b',      full_name: "Republic Act No. 3019",                          description: "the Anti-Graft and Corrupt Practices Act" },
  { abbreviation: "RA 6657",     pattern: '\bRA\s*6657\b',      full_name: "Republic Act No. 6657",                          description: "the Comprehensive Agrarian Reform Law" },
  { abbreviation: "RA 7160",     pattern: '\bRA\s*7160\b',      full_name: "Republic Act No. 7160",                          description: "the Local Government Code of the Philippines" },
  { abbreviation: "RA 7610",     pattern: '\bRA\s*7610\b',      full_name: "Republic Act No. 7610",                          description: "the Special Protection of Children Against Abuse, Exploitation and Discrimination Act" },
  { abbreviation: "RA 8293",     pattern: '\bRA\s*8293\b',      full_name: "Republic Act No. 8293",                          description: "the Intellectual Property Code of the Philippines" },
  { abbreviation: "RA 9165",     pattern: '\bRA\s*9165\b',      full_name: "Republic Act No. 9165",                          description: "the Comprehensive Dangerous Drugs Act of 2002" },
  { abbreviation: "RA 9262",     pattern: '\bRA\s*9262\b',      full_name: "Republic Act No. 9262",                          description: "the Anti-Violence Against Women and Their Children Act of 2004" },
  { abbreviation: "RA 9344",     pattern: '\bRA\s*9344\b',      full_name: "Republic Act No. 9344",                          description: "the Juvenile Justice and Welfare Act of 2006" },
  { abbreviation: "RA 9745",     pattern: '\bRA\s*9745\b',      full_name: "Republic Act No. 9745",                          description: "the Anti-Torture Act of 2009" },
  { abbreviation: "RA 10173",    pattern: '\bRA\s*10173\b',     full_name: "Republic Act No. 10173",                         description: "the Data Privacy Act of 2012" },
  { abbreviation: "RA 10667",    pattern: '\bRA\s*10667\b',     full_name: "Republic Act No. 10667",                         description: "the Philippine Competition Act" },
  { abbreviation: "RA 11232",    pattern: '\bRA\s*11232\b',     full_name: "Republic Act No. 11232",                         description: "the Revised Corporation Code of the Philippines" },
  { abbreviation: "RA 11313",    pattern: '\bRA\s*11313\b',     full_name: "Republic Act No. 11313",                         description: "the Safe Spaces Act" },
  { abbreviation: "PD 442",      pattern: '\bPD\s*442\b',       full_name: "Presidential Decree No. 442",                    description: "the Labor Code of the Philippines" },
  { abbreviation: "PD 1529",     pattern: '\bPD\s*1529\b',      full_name: "Presidential Decree No. 1529",                   description: "the Property Registration Decree" },
  { abbreviation: "PD 957",      pattern: '\bPD\s*957\b',       full_name: "Presidential Decree No. 957",                    description: "the Subdivision and Condominium Buyers Protective Decree" },
  { abbreviation: "EO 209",      pattern: '\bEO\s*209\b',       full_name: "Executive Order No. 209",                        description: "the Family Code of the Philippines" },
  { abbreviation: "RPC",         pattern: '\bRPC\b',            full_name: "the Revised Penal Code of the Philippines",      description: "the primary criminal law of the Philippines" },
  { abbreviation: "NCC",         pattern: '\bNCC\b',            full_name: "the New Civil Code of the Philippines",          description: "the primary civil law governing persons, family, property, and contracts" },
  { abbreviation: "ROC",         pattern: '\bROC\b',            full_name: "the Rules of Court of the Philippines",          description: "the procedural rules governing civil, criminal, and special proceedings" },
  { abbreviation: "LGC",         pattern: '\bLGC\b',            full_name: "the Local Government Code",                      description: "Republic Act No. 7160 governing local government units" },
  { abbreviation: "NIRC",        pattern: '\bNIRC\b',           full_name: "the National Internal Revenue Code",             description: "the primary tax law of the Philippines" },
  { abbreviation: "CIVIL CODE",  pattern: '\bCIVIL?\s*CODE\b',  full_name: "the Civil Code of the Philippines",             description: "the law governing civil relations" },
  { abbreviation: "LABOR CODE",  pattern: '\bLABOR\s*CODE\b',   full_name: "the Labor Code of the Philippines",             description: "Presidential Decree No. 442 governing employment and labor relations" },
  { abbreviation: "FAMILY CODE", pattern: '\bFAMILY\s*CODE\b',  full_name: "the Family Code of the Philippines",            description: "Executive Order No. 209 governing marriage, family, and property relations" }
]

laws.each do |law|
  record = PhilippineLaw.find_or_create_by!(abbreviation: law[:abbreviation]) do |p|
    p.pattern     = law[:pattern]
    p.full_name   = law[:full_name]
    p.description = law[:description]
    p.source      = "seeded"
    p.is_verified = true
  end

  puts "  #{record.previously_new_record? ? "Created" : "Found"} PhilippineLaw '#{record.abbreviation}'"
end

puts "==> Seeding complete."