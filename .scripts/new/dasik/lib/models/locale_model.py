from typing import List
from pydantic import BaseModel

class LocaleModel(BaseModel):
    selected_locales : List[str]
    desired_locale : str