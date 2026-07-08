# Rebuild game_over_screen.gd from clean HEAD content + apply 3 edits.
# Avoids unreliable terminal reads: authoritative source is git HEAD.
import subprocess, os

os.chdir(os.path.dirname(os.path.abspath(__file__)))
raw = subprocess.run(['git', 'show', 'HEAD:word_realm/scripts/ui/game_over_screen.gd'],
                     capture_output=True).stdout
src = raw.decode('utf-8')

NL = chr(10)

# --- Edit A: add scroll + count-label var + scroll step const ---
a_old = ("@onready var return_button: Button = $Panel/VBox/ReturnButton" + NL +
         NL + "signal return_to_menu")
a_new = ("@onready var return_button: Button = $Panel/VBox/ReturnButton" + NL +
         "@onready var scroll: ScrollContainer = $Panel/VBox/ScrollContainer" + NL +
         NL + "signal return_to_menu" + NL +
         NL + "# 结算词数标题（动态创建，show_screen 时复用）" + NL +
         "var _count_label: Label" + NL +
         "# 键盘滚动步长（约一行高度）" + NL +
         "const SCROLL_STEP := 28")
assert src.count(a_old) == 1, 'A count=%d' % src.count(a_old)
src = src.replace(a_old, a_new)

# --- Edit B: update word count after dedup ---
b_old = ("\t\t\tunique_words.append(w)" + NL + NL + "\t# Populate word rows")
b_new = ("\t\t\tunique_words.append(w)" + NL + NL +
         "\t_update_count_label(unique_words.size())" + NL + NL +
         "\t# Populate word rows")
assert src.count(b_old) == 1, 'B count=%d' % src.count(b_old)
src = src.replace(b_old, b_new)

# --- Edit C: append _input + _update_count_label after show_screen ---
c_old = "\treturn_button.pressed.connect(_on_return_pressed, CONNECT_ONE_SHOT)"
c_new = c_old + NL + NL + NL.join([
    "# 键盘滚动词表：↑↓ 逐行，PgUp/PgDn 整页，Home/End 到顶/底，Enter 返回菜单。",
    "# 鼠标滚轮由 ScrollContainer 原生支持，无需额外处理。",
    "func _input(event: InputEvent) -> void:",
    "\tif not visible:",
    "\t\treturn",
    "\tif not (event is InputEventKey and event.pressed):",
    "\t\treturn",
    "\tvar handled := true",
    "\tmatch event.keycode:",
    "\t\tKEY_UP:",
    "\t\t\tscroll.scroll_vertical -= SCROLL_STEP",
    "\t\tKEY_DOWN:",
    "\t\t\tscroll.scroll_vertical += SCROLL_STEP",
    "\t\tKEY_PAGEUP:",
    "\t\t\tscroll.scroll_vertical -= int(scroll.size.y)",
    "\t\tKEY_PAGEDOWN:",
    "\t\t\tscroll.scroll_vertical += int(scroll.size.y)",
    "\t\tKEY_HOME:",
    "\t\t\tscroll.scroll_vertical = 0",
    "\t\tKEY_END:",
    "\t\t\tscroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)",
    "\t\tKEY_ENTER, KEY_KP_ENTER:",
    "\t\t\t_on_return_pressed()",
    "\t\t_:",
    "\t\t\thandled = false",
    "\tif handled:",
    "\t\tget_viewport().set_input_as_handled()",
    "",
    "# 词数标题：动态创建 Label，插入到 Message 之后、ScrollContainer 之前，后续复用。",
    "func _update_count_label(n: int) -> void:",
    "\tif _count_label == null:",
    "\t\t_count_label = Label.new()",
    "\t\tvar vbox := $Panel/VBox",
    "\t\tvbox.add_child(_count_label)",
    "\t\tvbox.move_child(_count_label, message_label.get_index() + 1)",
    "\t_count_label.text = \"本局词汇回顾  %d 词\" % n",
])
assert src.count(c_old) == 1, 'C count=%d' % src.count(c_old)
src = src.replace(c_old, c_new)

with open('scripts/ui/game_over_screen.gd', 'w', encoding='utf-8', newline='\n') as f:
    f.write(src)

# Structural sanity: no duplicate top-level funcs
funcs = [l.split('(')[0][5:] for l in src.split(NL) if l.startswith('func ')]
from collections import Counter
dups = [n for n, k in Counter(funcs).items() if k > 1]
assert not dups, 'DUP FUNCS: %s' % dups

# success flag file (verified via reliable Glob channel)
open('REBUILD_OK.flag', 'w').write('funcs=%s' % ','.join(funcs))
