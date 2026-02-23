from enum import Enum


class Role(str, Enum):
    OWNER = "OWNER"
    MANAGER = "MANAGER"
    WORKER = "WORKER"
