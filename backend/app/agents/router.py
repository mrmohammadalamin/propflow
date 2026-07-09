from pydantic import BaseModel
from typing import Optional, Dict, Any
from app.models import User
import logging

logger = logging.getLogger(__name__)

class UserContext(BaseModel):
    user_id: int
    name: str
    role: str
    agency_id: int

class RouterAgent:
    def __init__(self, db_session):
        self.db = db_session

    def build_system_prompt(self, context: UserContext) -> str:
        """
        Injects user session context into the system prompt.
        """
        return (
            f"You are the main coordinator for Rent Collections A2UI. "
            f"You are currently assisting {context.name}, who has the role of '{context.role}'. "
            f"Always be polite, address them by their name, and remember they only have access to actions permitted by their role. "
            f"Route their requests to the appropriate sub-agent: Operations, Vision, Finance, Communications, Compliance, or Analytics."
        )

    def route_request(self, user_context: UserContext, prompt: str) -> Dict[str, Any]:
        """
        Determines which agent should handle the prompt using an LLM Orchestrator.
        """
        logger.info(f"Routing request for user {user_context.name}: {prompt}")
        from app.agents.gemini_agent import gemini_core
        import json
        
        system_prompt = self.build_system_prompt(user_context)
        orchestrator_prompt = f"""
        {system_prompt}
        
        The user said: "{prompt}"
        
        Analyze the request and decide which sub-agent should handle it.
        Available agents:
        - operations_agent: general queries, property management, adding entities
        - vision_agent: anything involving images, invoices, or scanning
        - finance_agent: money, arrears, ledgers, allocation
        - communications_agent: sending emails, texts, or messages to tenants/landlords
        - compliance_agent: gas safety, expiry, maintenance compliance
        - analytics_agent: charts, reports, total statistics
        
        Return ONLY a pure JSON object (no markdown formatting):
        {{
            "target_agent": "string (one of the above)",
            "reasoning": "string (why this agent was chosen)",
            "action_plan": "string (what the agent needs to do)",
            "ui_action": "string (set to 'add_property' if they want to add a property, 'none' otherwise)"
        }}
        """
        
        try:
            if not gemini_core.client:
                return self._fallback_routing(prompt)
                
            response = gemini_core.client.models.generate_content(
                model=gemini_core.model_name,
                contents=orchestrator_prompt
            )
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:-3]
            elif text.startswith("```"):
                text = text[3:-3]
            
            data = json.loads(text)
            
            return {
                "status": "routed_by_llm",
                "target_agent": data.get("target_agent", "operations_agent"),
                "reasoning": data.get("reasoning", "LLM determined routing"),
                "action_plan": data.get("action_plan", "Execute user request"),
                "ui_action": data.get("ui_action", "none"),
                "original_prompt": prompt
            }
        except Exception as e:
            logger.error(f"LLM routing failed: {e}")
            return self._fallback_routing(prompt)

    def _fallback_routing(self, prompt: str) -> Dict[str, Any]:
        logger.info("Using fallback keyword routing")
        lower_prompt = prompt.lower()
        if any(word in lower_prompt for word in ['email', 'message', 'text', 'tenant']):
            target_agent = "communications_agent"
        elif any(word in lower_prompt for word in ['invoice', 'receipt', 'bank statement']):
            target_agent = "vision_agent"
        elif any(word in lower_prompt for word in ['report', 'analytics', 'chart', 'how much']):
            target_agent = "analytics_agent"
        elif any(word in lower_prompt for word in ['gas safety', 'expire', 'maintenance']):
            target_agent = "compliance_agent"
        elif any(word in lower_prompt for word in ['arrears', 'ledger', 'balance', 'allocate']):
            target_agent = "finance_agent"
        else:
            target_agent = "operations_agent"

        return {
            "status": "routed",
            "target_agent": target_agent,
            "original_prompt": prompt
        }
