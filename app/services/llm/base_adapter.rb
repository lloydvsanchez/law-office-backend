module Llm
  class BaseAdapter
    def initialize(provider)
    @provider = provider
    end

    # Returns { content: String, prompt_tokens: Integer, completion_tokens: Integer }
    def generate(prompt:)
    raise NotImplementedError, "#{self.class}#generate must be implemented"
    end

    private

    def config
    @provider.config || {}
    end

    def model
    @provider.model
    end
    
    def system_prompt
      <<~PROMPT
        You are an expert Philippine legal document drafter.
    
        YOUR RESPONSE MUST BE A SINGLE VALID JSON OBJECT — nothing else before or after it.
        No markdown, no code fences, no explanations, no introductory text.
        All string values in the JSON must be properly escaped.
        In the "content" field, represent line breaks as \\n and escape all double quotes as \\".
    
        The JSON object must have exactly these four keys:
        - "title": the proper formal title of the document (e.g. "Deed of Absolute Sale")
        - "content": the full document template text with [VARIABLE_NAME] placeholders, as a single escaped string
        - "practice_area": one of civil, criminal, corporate, labor, family, property, taxation, immigration, administrative, intellectual_property
        - "document_type": a short document type label (e.g. "contract", "deed", "affidavit", "motion", "petition", "resolution", "agreement")
    
        When drafting the "content" value, apply the appropriate Philippine legal structure based on the document type:
    
        FOR LITIGATION & SPECIAL PROCEEDINGS (Petitions, Complaints, Motions, Court Scripts):
        - Include a formal Judicial Caption at the top (Court, Branch, Case Title, Sp. Proc/Civil Case Number).
        - For Petitions/Complaints, include signature blocks and a Verification and Certification Against Forum Shopping.
        - For Scripts, format clearly with character cues (e.g., PRESIDING JUDGE:, COURT INTERPRETER:).
    
        FOR SWORN STATEMENTS (Affidavits, Joint Statements, Criminal Complaint-Affidavits):
        - Include the Venue/Scilicet at the top ("Republic of the Philippines... S.S.").
        - Use numbered paragraphs starting with standard introductory phrases (e.g., "I, [NAME], after having been duly sworn...").
        - Conclude with a standard JURAT ("Subscribed and Sworn to before me...").
    
        FOR CONTRACTS & AGREEMENTS (Deeds of Sale, Leases, Waivers, NDAs):
        - Include a Title, Preamble identifying the parties, and Witnesseth/Recital clauses ("WHEREAS...").
        - Conclude with Signature Blocks for parties and instrumental witnesses.
        - Conclude with a formal NOTARIAL ACKNOWLEDGMENT ("Before me, a Notary Public...").
    
        FOR CORRESPONDENCE & ADMINISTRATIVE DOCUMENTS (Demand Letters, Board Resolutions, Authorizations):
        - For Letters: Use standard formal business letter layout (Date, Inside Address, Subject Line, Salutation, Body, Sign-off, and an optional Acknowledgement of Receipt line at the bottom).
        - For Resolutions: Use "WHEREAS" clauses followed by "RESOLVED, AS IT IS HEREBY RESOLVED..." blocks.
    
        Use uppercase placeholder variables in the format [VARIABLE_NAME] for all dynamic fields (e.g., [NAME], [DATE], [ADDRESS]).
        Use bold uppercase for party designations like SELLER, BUYER, PETITIONER, RESPONDENT.
    
        If the user request lacks sufficient legal context to determine the document type, respond with this exact JSON:
        {"title": "Clarification Needed", "content": "Please provide more context about the type of legal document you need.", "practice_area": "", "document_type": ""}
      PROMPT
    end
  end
end