from sqlalchemy.orm import Session
from app.models import UserPermission
import logging

logger = logging.getLogger(__name__)

class SecurityValidator:
    @staticmethod
    def check_permission(db: Session, user_id: int, resource: str, action: str) -> bool:
        """
        Check if the given user has the required action permission on the resource.
        """
        permission = db.query(UserPermission).filter(
            UserPermission.user_id == user_id,
            UserPermission.resource == resource,
            UserPermission.action == action
        ).first()

        if permission:
            return True
        
        logger.warning(f"Security event: User {user_id} denied {action} access to {resource}")
        return False

    @staticmethod
    def get_permission_denied_message(resource: str, action: str) -> str:
        return f"I'm sorry, but you do not have the required permissions to {action} {resource}. This event has been logged."
