# GTK 3 stylesheets for windows with a class.
#
# scope-css.py theme <class> <assets> < theme.css: the theme, for windows with
# the class. Each selector matches inside the window and, where its first part
# can be the window itself, the window too. Named colors are global in GTK, so
# @define-color is inlined into the rules instead; keyframes are renamed per
# class. Relative urls are resolved against <assets>.
#
# scope-css.py fade <class> < theme.css: text color transitions for windows with
# the class, on the nodes the theme gives a color. GTK 3 doesn't update a color
# a node inherits while it's transitioning, so only the nodes setting one may
# transition it; their descendants follow them.
import sys

import tinycss2
from tinycss2 import ast

FADED = 'background-color, background-image, color, border-color, box-shadow'

mode, scope = sys.argv[1], sys.argv[2]
assets = sys.argv[3] if mode == 'theme' else None
rules = tinycss2.parse_stylesheet(sys.stdin.read(), skip_comments=True, skip_whitespace=True)

named_colors = {}
keyframes = set()
for rule in rules:
    if isinstance(rule, ast.AtRule) and rule.lower_at_keyword == 'define-color':
        tokens = [t for t in rule.prelude if not isinstance(t, ast.WhitespaceToken)]
        named_colors[tokens[0].value] = rule.prelude[rule.prelude.index(tokens[0]) + 1:]
    elif isinstance(rule, ast.AtRule) and rule.lower_at_keyword == 'keyframes':
        keyframes.add(tinycss2.serialize(rule.prelude).strip())


def keyframe_name(name):
    return f'{scope}-{name}'


def url(token, path):
    return ast.URLToken(token.source_line, token.source_column, path, f'url("{path}")')


def resolve(tokens):
    """The tokens with named colors, keyframe names and relative urls resolved."""
    out = []
    for token in tokens:
        if isinstance(token, ast.AtKeywordToken) and token.value in named_colors:
            out.extend(resolve(named_colors[token.value]))
        elif isinstance(token, ast.IdentToken) and token.value in keyframes:
            out.append(ast.IdentToken(token.source_line, token.source_column, keyframe_name(token.value)))
        elif isinstance(token, ast.URLToken) and ':' not in token.value:
            out.append(url(token, f'{assets}/{token.value}'))
        elif isinstance(token, ast.FunctionBlock) and token.lower_name == 'url':
            path = token.arguments[0].value
            out.append(url(token, path if ':' in path else f'{assets}/{path}'))
        elif isinstance(token, ast.FunctionBlock):
            token.arguments = resolve(token.arguments)
            out.append(token)
        elif isinstance(token, (ast.ParenthesesBlock, ast.SquareBracketsBlock, ast.CurlyBracketsBlock)):
            token.content = resolve(token.content)
            out.append(token)
        else:
            out.append(token)
    return out


def split_selectors(prelude):
    selectors, current = [], []
    for token in prelude:
        if isinstance(token, ast.LiteralToken) and token.value == ',':
            selectors.append(current)
            current = []
        else:
            current.append(token)
    selectors.append(current)
    return [tinycss2.serialize(s).strip() for s in selectors]


def type_end(selector):
    """Where the first compound's type selector (if any) ends."""
    i = 0
    while i < len(selector) and (selector[i].isalnum() or selector[i] in '-_*'):
        i += 1
    return i


def scoped(selector):
    yield f'.{scope} {selector}'
    # The window itself is a window, so only compounds without another type
    # can match it.
    end = type_end(selector)
    if selector[:end] in ('', '*', 'window'):
        yield f'{selector[:end]}.{scope}{selector[end:]}'


def declarations(content):
    return tinycss2.serialize(resolve(content)).strip()


def sets_color(rule):
    return any(isinstance(d, ast.Declaration) and d.lower_name == 'color'
               for d in tinycss2.parse_declaration_list(rule.content))


def fade():
    selectors = {s for rule in rules if isinstance(rule, ast.QualifiedRule) and sets_color(rule)
                 for selector in split_selectors(rule.prelude) if selector != '*'
                 for s in scoped(selector)}
    return [f'{", ".join(sorted(selectors))} {{ transition-property: {FADED}; }}']


def theme():
    out = []
    for rule in rules:
        if isinstance(rule, ast.QualifiedRule):
            selectors = [s for selector in split_selectors(rule.prelude) for s in scoped(selector)]
            out.append(f'{", ".join(selectors)} {{ {declarations(rule.content)} }}')
        elif isinstance(rule, ast.AtRule) and rule.lower_at_keyword == 'keyframes':
            name = tinycss2.serialize(rule.prelude).strip()
            out.append(f'@keyframes {keyframe_name(name)} {{ {declarations(rule.content)} }}')
        elif isinstance(rule, ast.AtRule) and rule.lower_at_keyword in ('define-color', 'import'):
            pass
        else:
            sys.exit(f'scope-css.py: unexpected {rule.type} {getattr(rule, "at_keyword", "")}')
    return out


print('\n'.join(theme() if mode == 'theme' else fade()))
