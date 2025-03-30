from typing import List, Literal, Optional
from pydantic import BaseModel, Field

class NetworkModel(BaseModel):
    type : Literal["NetworkManager", "systemd-networkd"]
    add_default_hosts : bool = False