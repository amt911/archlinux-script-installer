from pathlib import Path
from .abstract_action import AbstractAction
from ..command_worker.command_worker import Command
import re

class LocaleAction(AbstractAction):
    def __init__(self, prop : dict):
        
        self._KEY_NAME = "locales"
        self._can_incrementally_change = True
        
        self._selected_locales = prop[self._KEY_NAME]["selected_locales"]
        self._desired_locale = prop[self._KEY_NAME]["desired_locale"]
        self._desired_tty_layout = prop[self._KEY_NAME]["desired_tty_layout"]
        
    @property
    def KEY_NAME(self) -> str:
        return self._KEY_NAME
    
    @property
    def can_incrementally_change(self) -> bool:
        return self._can_incrementally_change            
    
    
    def _before_check(self) -> bool:
        with open("/mnt/etc/locale.gen", "r") as locale_gen:
            locale_gen_str = locale_gen.read()
            uncommented_lines = re.findall(r"^[a-z]+_\S+ \S+", locale_gen_str, re.MULTILINE)
            uncommented_lines_num = len(uncommented_lines)
            
            # First, check the number of uncommented lines and compare with the array length
            if (uncommented_lines_num != len(self._selected_locales)):
                return True
            
            for i in self._selected_locales:
                # Also check that the uncommented lines are the same than on the declarative file
                if re.search(rf"^{re.escape(i)}", locale_gen_str, re.MULTILINE) is None:
                    return True
                
            locale_conf_path = Path("/mnt/etc/locale.conf")

            # Check if the conf file exists
            if not locale_conf_path.exists():
                return True
            
            # If the file exists, check whether the content is right
            with open("/mnt/etc/locale.conf", "r") as locale_conf:
                locale_conf_str = locale_conf.read()
                
                # If the file does not contain the selected locale, then return true
                if re.search(rf"{re.escape(self._desired_locale)}", locale_conf_str) is None:
                    return True

            tty_layout_path = Path("/mnt/etc/vconsole.conf")

            # Check if the conf file exists
            if not tty_layout_path.exists():
                return True
            
            # If the file exists, check whether the content is right
            with open("/mnt/etc/vconsole.conf", "r") as vconsole_conf:
                vconsole_conf_str = vconsole_conf.read()
                
                # If the file does not contain the selected locale, then return true
                if re.search(rf"{re.escape(self._desired_tty_layout)}", vconsole_conf_str) is None:
                    return True
            
        return False
    
    def after_check(self):
        pass
    
    def _comment_all_entries(self):
        with open("/mnt/etc/locale.gen", "r+") as locale_gen:
            locale_gen_str = locale_gen.read()
            locale_gen.seek(0)
            
            locale_gen_str = re.sub(r"(^[a-z]+)", r"#\1", locale_gen_str, 0, re.MULTILINE)
            
            locale_gen.write(locale_gen_str)        
    
    def do_action(self):
        if self._before_check():
            # First, we comment all entries to have a clean file
            self._comment_all_entries()
            
            with open("/mnt/etc/locale.gen", "r+") as locale_gen:
                locale_gen_str = locale_gen.read()
                locale_gen.seek(0)
                
                for i in self._selected_locales:
                    locale_gen_str = locale_gen_str.replace(f"#{i}", f"{i}")
                
                locale_gen.write(locale_gen_str)
                    
            with open("/mnt/etc/locale.conf", "w") as locale_conf:
                locale_conf.write(f"LANG={self._desired_locale}")
                
            with open("/mnt/etc/vconsole.conf", "w") as vconsole_conf:
                vconsole_conf.write(f"KEYMAP={self._desired_tty_layout}") 
                               
            print(Command.execute("locale-gen", [], True).stdout.decode())