import os
import json
from google import genai
from typing import Dict, Any

class GeminiAgenticCore:
    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        try:
            self.client = genai.Client(api_key=api_key) if (api_key and api_key != "your_gemini_api_key_here") else None
        except Exception:
            self.client = None
        self.model_name = 'gemini-2.5-pro'
        self.vision_model_name = 'gemini-2.5-flash'


    async def parse_voice_command(self, transcript: str) -> Dict[str, Any]:
        """
        Takes a transcribed voice command and converts it into a structured JSON action.
        """
        prompt = f"""
        You are an AI assistant for a Property Management SaaS platform.
        Your job is to parse the following user command and extract the intent and entities.
        
        Command: "{transcript}"
        
        Respond ONLY with a valid JSON object matching this schema:
        {{
            "intent": "log_invoice" | "query_arrears" | "allocate_payment" | "unknown",
            "entities": {{
                "amount": float (or null),
                "property_identifier": string (or null),
                "description": string (or null),
                "category": string (e.g. 'plumbing', 'electrical') (or null)
            }}
        }}
        """
        
        try:
            if not self.client:
                return {"error": "Gemini API key not configured.", "intent": "unknown"}
                
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt
            )
            # Clean up the response to ensure it's pure JSON
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:-3]
            return json.loads(text)
        except Exception as e:
            return {"error": str(e), "intent": "unknown"}

    async def parse_invoice_vision(self, image_bytes: bytes, mime_type: str) -> Dict[str, Any]:
        """
        Takes an image of an invoice and extracts data.
        """
        prompt = """
        You are an expert accountant for a property management company.
        Analyze this image of a contractor invoice or receipt.
        Extract the following information and return it as a pure JSON object:
        
        {{
            "contractor_name": string (or null),
            "total_amount": float (or null),
            "property_address_mentioned": string (or null),
            "service_description": string (or null),
            "invoice_date": string (YYYY-MM-DD) (or null)
        }}
        """
        
        try:
            if not self.client:
                return {"error": "Gemini API key not configured."}
                
            from google.genai import types
            
            response = self.client.models.generate_content(
                model=self.vision_model_name,
                contents=[
                    prompt,
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type)
                ]
            )
            return json.loads(text)
        except Exception as e:
            return {"error": str(e)}

    async def verify_tenant_id(self, image_bytes: bytes, mime_type: str, expected_name: str, expected_address: str) -> Dict[str, Any]:
        """
        Analyzes a tenant's Proof of ID and verifies it against expected details.
        """
        prompt = f"""
        You are a compliance officer for a UK property management company.
        Verify this Proof of ID (Passport, Driving License, or ID Card).
        
        Compare the text on the document with these EXPECTED details:
        Name: {expected_name}
        Current Address: {expected_address}
        
        Extract information and return it as a pure JSON object:
        {{
            "verified": boolean,
            "reasoning": string (explain why it matched or didn't match),
            "document_type": string (e.g. 'Passport', 'Driving License'),
            "extracted_name": string (full name exactly as it appears on document),
            "extracted_address": string (full address exactly as it appears on document or null if not present)
        }}
        
        Rules:
        - If the Name matches exactly or is very similar (e.g. missing middle name), set verified: true.
        - If the Address matches, it's a strong verification. If the address is different but the name matches, set verified: false but mention in reasoning that name matched.
        - If the image is not an ID document, set verified: false.
        """
        
        try:
            if not self.client:
                return {"error": "Gemini API key not configured.", "verified": False, "reasoning": "AI disabled"}
                
            from google.genai import types
            
            response = self.client.models.generate_content(
                model=self.vision_model_name,
                contents=[
                    prompt,
                    types.Part.from_bytes(data=image_bytes, mime_type=mime_type)
                ]
            )
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:-3]
            return json.loads(text)
        except Exception as e:
            return {"error": str(e), "verified": False, "reasoning": "AI processing error"}

gemini_core = GeminiAgenticCore()
