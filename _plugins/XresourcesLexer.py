from pygments.lexer import RegexLexer, bygroups
from pygments.token import Text, Comment, Operator, Keyword, Name, String


def recursive_merge(a, b):
    """Recursively merge two dicts. Updates a."""
    if not isinstance(b, dict):
        return b
    for k, v in b.items():
        if k in a and isinstance(a[k], dict):
            a[k] = recursive_merge(a[k], v)
        else:
            a[k] = v
    return a


class XresourcesLexer(RegexLexer):
    """
    Lexer for configuration files in INI style.
    """

    name = 'Xresources'
    aliases = ['Xresources']
    filenames = ['.Xresources']
    mimetypes = []

    tokens = {
        'root': [
            (r'\s+', Text),
            (r'!.*', Comment.Single),
            (r'\[.*?\]$', Keyword),
            (r'(.*?)([ \t]*)(:)([ \t]*)(.*(?:\n[ \t].+)*)',
             bygroups(Name.Attribute, Text, Operator, Text, String))
        ]
    }

    def analyse_text(text):
        npos = text.find('\n')
        if npos < 3:
            return False
        return text[0] == '[' and text[npos-1] == ']'


def setup(builder):

    # publish it in some arbitrary module:
    import blogdown
    blogdown.XresourcesLexer = XresourcesLexer

    from pkg_resources import EntryPoint, Requirement, working_set
    pygments_dist = working_set.find(Requirement.parse('pygments'))

    entry_map_section = """
        [pygments.lexers]
        Xresources = blogdown:XresourcesLexer
    """

    recursive_merge(
        pygments_dist.get_entry_map(),
        EntryPoint.parse_map(entry_map_section, pygments_dist))
