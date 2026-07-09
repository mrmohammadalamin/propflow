import json
from google import genai
from typing import List, Dict, Any
import os

class ReconciliationAgent:
    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        try:
            self.client = genai.Client(api_key=api_key) if (api_key and api_key != "your_gemini_api_key_here") else None
        except Exception:
            self.client = None
        self.model_name = 'gemini-1.5-pro'

    async def auto_allocate(self, bank_statement_text: str, active_tenancies_context: str) -> Dict[str, Any]:
        """
        Uses Gemini to reconcile bank statement entries against known active tenancies.
        """
        prompt = f"""
        You are an expert AI Bank Reconciliation Agent for a Property Management SaaS.
        Your task is to match incoming bank transactions to the correct active tenancy.
        
        ### Active Tenancies (Your Context)
        {active_tenancies_context}
        
        ### Unallocated Bank Statement Entries
        {bank_statement_text}
        
        ### Instructions
        Analyze the bank statement. For each transaction, attempt to find a matching tenancy based on:
        1. Exact or partial match of the Rent Amount.
        2. Names or addresses mentioned in the Bank Reference.
        
        Return a JSON object containing an array of matches and an array of unallocated entries.
        Format strictly as:
        {{
            "allocated": [
                {{
                    "transaction_date": "YYYY-MM-DD",
                    "bank_reference": "string",
                    "amount": float,
                    "matched_tenancy_id": int,
                    "confidence": "high" | "medium" | "low",
                    "reasoning": "string explaining why this match was made"
                }}
            ],
            "unallocated_requires_human": [
                {{
                    "transaction_date": "YYYY-MM-DD",
                    "bank_reference": "string",
                    "amount": float,
                    "reasoning": "string explaining why no match was found"
                }}
            ]
        }}
        """
        
        try:
            if not self.client:
                return {"error": "Gemini API key not configured.", "unallocated_requires_human": []}
                
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt
            )
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:-3]
            return json.loads(text)
        except Exception as e:
            return {"error": str(e)}

allocator_agent = ReconciliationAgent()
