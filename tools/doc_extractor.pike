//
// The MIT License (MIT)
//
// Copyright (c) 2016 Paweł Tomak <pawel@tomak.eu>
//
// This tool is based on Pike's Tools.Standalone.extract_autodoc and credits
// and thanks for that go to Henrik Grubbström (Grubba) <grubba@grubba.org> and
// Contributors.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

inherit Tools.Standalone.extract_autodoc;

#pike __REAL_VERSION__

constant description = "Extracts docs from Pike or C code and stores them in"
" more friendly ay for PikeDoc vim plugin.";

protected int width = 80;
protected int columns = 1;

string line(void|int w)
{
    return sprintf("\n%'-'" + (w || min(80, width)) + "s\n", "");
}

mapping(string:array(string)|int) wrap_text(string text, int max_width)
{
    array(string) words = String.trim_all_whites(text)/" ";
    array(string) ret;
    foreach (words, string word)
    {
        if (!ret)
            ret = ({ word });
        else if (strlen(ret[-1] || "") + strlen(word) < max_width)
        {
            ret[-1] = ({ ret[-1], word })*" ";
        }
        else
            ret += ({ word });
    }

    return ([ "#lines": sizeof(ret), "text": ret ]);
}

string
get_table(array(string) entries, void|int sep, void|int cols, void|bool wrap)
{
    if (!entries || !sizeof(entries))
        return "";

    cols = cols || columns;

    array(array(string)) column_strings = entries/(float)(sizeof(entries)/(float)cols);
    array(int) column_widths = allocate(sizeof(column_strings));
    int num_entries_in_column = sizeof(column_strings[0]);
    foreach (column_strings; int i; array(string) col_entries)
    {
        if (sizeof(col_entries) == 1)
        {
            column_widths[i] = strlen(col_entries[0]);
        }
        else
        {
            column_widths[i] = Array.reduce(lambda(string|int arg1, string arg2)
                    {
                        int s1 = stringp(arg1) ? strlen(arg1) : arg1;
                        int s2 = strlen(arg2);
                        return (s1 > s2) ? s1 : s2;
                    }, col_entries);
        }

        if (sizeof(col_entries) < num_entries_in_column)
            column_strings[i] += ({ "" });
    }

    int sep_lenght = ((!undefinedp(sep)) ? 4 + 3 * (cols-1) : (cols-1));
    if ((sep_lenght + Array.sum(column_widths)) > width)
    {
        if (!wrap)
            return (cols-1) ? get_table(entries, sep, cols-1) : "";
        else
        {
            int longest_width = max(@column_widths);
            int longest_column = search(column_widths, longest_width);
            int max_width = width - sep_lenght -
                (Array.sum(column_widths) - longest_width);
            array(array(string)) wrapped_columns =
                ({ ({ }) })*sizeof(column_widths);
            for (int i = 0; i < sizeof(column_strings[0]); i++)
            {
                mapping(string:array(string)|int) wrapped =
                    wrap_text(column_strings[longest_column][i], max_width);
                for (int inner = 0; inner < sizeof(column_strings); inner++)
                {
                    if (inner != longest_column)
                    {
                        wrapped_columns[inner] += ({ column_strings[inner][i] });
                        if (wrapped["#lines"] > 1)
                        {
                            wrapped_columns[inner] +=
                                (({ ({ "" }) })*(wrapped["#lines"]-1))*({  });
                        }
                    }
                    else
                    {
                        wrapped_columns[inner] += wrapped["text"];
                    }
                }
            }
            column_widths[longest_column] = max_width;
            column_strings = wrapped_columns;
        }
    }

    string ret = "";
    array(string) col_patterns = allocate(sizeof(column_widths));
    foreach (column_widths; int i; int w)
    {
        col_patterns[i] = "%-' '" + w + "s";
    }
    string pattern;
    if (!undefinedp(sep))
    {
        pattern = sprintf("%c %s %c\n", sep,
                col_patterns * sprintf(" %c ", sep), sep);
    }
    else
        pattern = col_patterns*" " + "\n";

    for (int i = 0; i < sizeof(column_strings[0]); i++)
        ret += sprintf(pattern, @column(column_strings, i));

    return ret;
}

string clear_name(string name)
{
    if (!name)
        return name;

    if ((<"`!", "`%", "`&", "`", "`*", "`+", "`+=", "`-", "`->", "`->=", "`/",
        "`<", "`<<", "`==", "`>", "`>>", "`[..]", "`[]", "`[]=", "`^", "``%",
        "``&", "``*", "``+", "``-", "``/", "``<<", "``>>", "``^", "``|", "`|",
        "`~", "`()", "`!=", "`<=", "`>=">)[name])
    {
        return name;
    }

    name = replace(name, "->", ".");
    name = replace(name, "::", ".");
    Regexp.PCRE.Plain r = Regexp.PCRE.Plain("[^a-zA-Z0-9_.-]");
    name = r.replace(name, "");
    r = Regexp.PCRE.Plain("^[.]+");
    name = r.replace(name, "");
    r = Regexp.PCRE.Plain("[.]+$");
    name = r.replace(name, "");

    return name;
}

class Base
{
    protected string name;
    protected mapping(string:string) attributes;
    protected array(Parser.XML.Tree.SimpleNode) nodes = ({ });

    string get_string() { return "Base"; }

    void create() { };

    protected void prepare(mapping(string:string) attrs)
    {
        if (!name)
        {
            attributes = attrs;
            name = attrs->name;
        }
        name = clear_name(name);
    }

    void process_node(Parser.XML.Tree.SimpleNode node);

    void parse(Parser.XML.Tree.SimpleNode node)
    {
        nodes += ({ node });
        prepare(node->get_attributes() || ([ ]));
        process_node(node);
    }

    string get_name(bool vimsyntax)
    {
        if (vimsyntax)
            return sprintf("*%s*", name || "");

        return name;
    }

    mixed cast(string t)
    {
        return get_string();
    }

    string _sprintf()
    {
        return get_string();
    }

    void debug()
    {
        werror("Node: %O : attrs: %O, nodes: %O\n", name, attributes,nodes);
    }
}

class Types
{
    inherit Base;
    private array(string) types = ({ });

    private string parse_type(Parser.XML.Tree.SimpleNode type_node)
    {
        string type_name = type_node->get_any_name();
        switch (type_name)
        {
            case "int":
                array(string) vals = ({ });
                foreach (type_node->get_elements(), Parser.XML.Tree.SimpleNode e)
                {
                    string element_name = e->get_any_name();
                    if (element_name == "min" || element_name == "max")
                        vals += ({ (string)e->value_of_node() });
                }
                return "int" + ((sizeof(vals) == 2) ? "(" + vals*".." + ")" : "");
            break;

            default:
                return type_name;
        }
    }

    protected void process_node(Parser.XML.Tree.SimpleNode node)
    {
        Parser.XML.Tree.SimpleNode child = node->get_first_element();
        if (child->get_any_name() == "or")
        {
            foreach (child->get_elements(), Parser.XML.Tree.SimpleNode c)
                types += ({ parse_type(c) });

            if (has_value(types, "void"))
                types = ({ "void" }) + (types - ({ "void" }));
        }
        else
            types = ({ parse_type(child) });
    }

    string get_string()
    {
        return sprintf("%s", types*"|");
    }
}

class Modifiers
{
    inherit Base;
    private array(string) modifiers = ({ });

    protected void process_node(Parser.XML.Tree.SimpleNode node)
    {
        foreach (node->get_elements("modifiers"), Parser.XML.Tree.SimpleNode m)
        {
            foreach (m->get_children(), Parser.XML.Tree.SimpleNode c)
                modifiers += ({ c->get_any_name() });
        }
    }

    string get_string()
    {
        return sprintf("%s", modifiers*" ");
    }
}

class Value
{
    inherit Base;
    private string value;

    protected void process_node(Parser.XML.Tree.SimpleNode node)
    {
        value = (string)node->value_of_node();
    }

    string get_string()
    {
        return value;
    }
}

class Argument
{
    inherit Base;

    private Types types;
    private Value value;

    protected void process_node(Parser.XML.Tree.SimpleNode node)
    {
        if (Parser.XML.Tree.SimpleNode v = node->get_first_element("value"))
        {
            value = Value();
            value->parse(v);
        }
        else
        {
            types = Types();
            types->parse(node->get_first_element("type"));
        }
    }

    string get_string()
    {
        if (value)
            return (string)value;

        return sprintf("%s%s%s", types, name && " " || "", name || "");
    }
}

class Method
{
    inherit Base;

    private array(Argument) args = ({ });
    private Types returns;
    private Modifiers modifiers;

    protected void process_node(Parser.XML.Tree.SimpleNode node)
    {
        Parser.XML.Tree.SimpleNode argument_nodes =
            node->get_first_element("arguments");

        foreach (argument_nodes->get_elements("argument"),
            Parser.XML.Tree.SimpleNode child)
        {
            Argument arg = Argument();
            arg->parse(child);
            args += ({ arg });
        }

        returns = Types();
        returns->parse(node->get_first_element("returntype"));

        if (node->get_elements("modifiers"))
        {
            modifiers = Modifiers();
            modifiers->parse(node);
        }
    }

    string get_string()
    {
        return sprintf("%s%s %s(%s)",
            modifiers ? modifiers->get_string() + " " : "", returns,
            get_name(0), args->get_string()*", ");
    }
}

class Variable
{
    inherit Base;

    private Types types;

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        types = Types();
        types->parse(node);
    }

    string get_string()
    {
        return sprintf("%s", types);
    }
}

class Inherit
{
    inherit Base;
    protected string classname;
    protected Modifiers modifiers;

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        Parser.XML.Tree.SimpleNode n = node->get_first_element("classname");
        if (n)
            classname = clear_name(n->value_of_node() || name);

        if (node->get_elements("modifiers"))
        {
            modifiers = Modifiers();
            modifiers->parse(node);
        }
    }

    string get_classname(bool vimsyntax)
    {
        if (vimsyntax)
            return sprintf("*%s*", classname);

        return classname;
    }

    string get_string()
    {
        return sprintf("%s%s",
            modifiers ? modifiers->get_string() + " " : "", get_classname(1));
    }
}

class Constant
{
    inherit Base;

    void process_node(Parser.XML.Tree.SimpleNode node) {}

    string get_string()
    {
        return sprintf("Constant %s", name);
    }
}

class Directive
{
    inherit Base;

    void process_node(Parser.XML.Tree.SimpleNode node) {}

    string get_string()
    {
        return sprintf("%s", name);
    }
}

class TextNode
{
    protected string text = "";
    protected string name;
    protected Parser.XML.Tree.SimpleNode self;

    void create(Parser.XML.Tree.SimpleNode node)
    {
        self = node;
        name = self->get_any_name();
        array(array(string)) table = ({ });

        if (self->get_node_type() == Parser.XML.Tree.XML_TEXT)
            text = self->value_of_node();
        else
        {
            foreach (self->get_children(), Parser.XML.Tree.SimpleNode c)
            {
                if (name == "ref")
                    text += sprintf("*%s*", TextNode(c)->get_string());
                else if (name == "int" && c->get_any_name() == "group")
                {
                    Group g = Group();
                    g->parse(c);
                    table += ({
                        ({ g->get_value(true) || "", g->get_text(true) || "" })
                        });
                }
                else
                    text += TextNode(c)->get_string();
            }
            if (name == "int" && sizeof(table))
            {
                text += sprintf("\n%s\n",
                        get_table(column(table, 0) + column(table, 1), '|', 2, true));
            }
        }
    }

    string get_string()
    {
        if (self->get_any_name() == "p")
        {
            string ret = "";
            foreach (text/"\n", string line)
            {
                ret += sprintf("    %s\n", String.trim_all_whites(line));
            }

            return sprintf("%s", ret);
        }

        return text;
    }
}

class Group
{
    inherit Base;
    protected string type;
    protected string text;
    protected string value;

    string get_type() { return type; }

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        foreach (node->get_elements(), Parser.XML.Tree.SimpleNode e)
        {
            string ename = e->get_any_name();
            if (ename == "text")
            {
                if (text)
                    text += line() + TextNode(e)->get_string();
                else
                    text = TextNode(e)->get_string();
            }
            else if (ename == "value")
                value = TextNode(e)->get_string();
            else
            {
                type = ename;
                mapping(string:string) attrs = e->get_attributes();
                name = attrs->name || UNDEFINED;
            }
        }
    }

    string get_text(void|bool clean)
    {
        if (clean)
            return String.trim_all_whites(String.normalize_space(text || ""));
        else
            return String.trim_all_whites(text || "");
    }

    string get_value(void|bool clean)
    {
        if (clean)
            return String.trim_all_whites(String.normalize_space(value || ""));
        else
            return String.trim_all_whites(value || "");
    }

    string get_string()
    {
        return sprintf("%s%s%s", String.capitalize(type),
            name ? " " + name : "", text ? "\n    " + get_text() : "");
    }
}

class Doc
{
    inherit Base;
    private string description;
    private array(Group) groups = ({ });

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        Parser.XML.Tree.SimpleNode text = node->get_first_element("text");
        if (text)
        {
            if (description)
                description += line() + TextNode(text)->get_string();
            else
                description = TextNode(text)->get_string();
        }

        foreach (node->get_elements("group"), Parser.XML.Tree.SimpleNode g)
        {
            Group group = Group();
            group->parse(g);
            if (!group->get_string())
            {
                werror("Missing text for group node: %O, group name: %O, "
                        "value: %O, "
                        "parent: %O, parent_name:%O\n", g, group->name,
                        g->value_of_node(), node, name);
            }
            else
                groups += ({ group });
        }
    }

    string get_string()
    {
        string ret = "";
        if (description)
            ret = sprintf("Description\n%s", description);

        if (sizeof(groups))
            ret += groups->get_string()*"\n\n";

        return ret;
    }
}

class DocGroup
{
    inherit Base;
    protected void process_node(Parser.XML.Tree.SimpleNode node);

    void save(string parent_path)
    {
        string encoded_name = Protocols.HTTP.uri_encode(name);
        if (strlen(encoded_name) < 1)
        {
            werror("%s:%d: Unhandled or unnamed entity: %O\n", (__FILE__/"/")[-1],
                __LINE__, get_string());
            return;
        }

        string filename = combine_path(parent_path, encoded_name) + ".txt";

        string content = string_to_utf8(get_string());
        if (Stdio.exist(filename))
            Stdio.append_file(filename, ({ line(), content })*"\n");
        else
            Stdio.write_file(filename, content);
    }
}

class DocMethod
{
    inherit DocGroup;
    array(Method) methods = ({ });
    Doc doc;

    void create(string n, array(Method) m, Doc d)
    {
        name = n;
        methods = m;
        doc = d;
    }

    string get_string()
    {
        return sprintf("Method %s()%s%s%s", get_name(1), line(),
            "    "+methods->get_string()*"\n    ",
            doc ? "\n\n" + doc->get_string() : "");
    }
}

class DocGroupM
{
    inherit DocGroup;
    array(DocMethod) docmethods = ({ });
    protected string parent_path;

    void create(string _parent_path)
    {
        parent_path = _parent_path;
    }

    protected void process_node(Parser.XML.Tree.SimpleNode node)
    {
        array(Method) methods = ({ });
        Doc d;
        Parser.XML.Tree.SimpleNode docnode = node->get_first_element("doc");
        if (docnode)
        {
            d = Doc();
            d->parse(docnode);
        }

        foreach (node->get_elements("method"), Parser.XML.Tree.SimpleNode m)
        {
            Method method = Method();
            method->parse(m);
            methods += ({ method });
        }

        if (name)
            docmethods += ({ DocMethod(name, methods, d) });
        else
        {
            foreach (methods, Method m)
                docmethods += ({ DocMethod(m->get_name(0), methods, d) });
        }
    }
}

class DocGroupV
{
    inherit DocGroup;
    private Doc doc;
    private Variable variable;

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        doc = Doc();
        doc->parse(node->get_first_element("doc"));
        variable = Variable();
        variable->parse(node->get_first_element("variable"));
    }

    string get_string()
    {
        return sprintf("Variable %s%s", variable,
            doc ? "\n\n" + doc->get_string() : "");
    }
}

class DocGroupC
{
    inherit DocGroup;
    Doc doc;
    private array(Constant) constants = ({ });

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        if (node->get_first_element("doc"))
        {
            doc = Doc();
            doc->parse(node->get_first_element("doc"));
        }

        foreach (node->get_elements("constant"), Parser.XML.Tree.SimpleNode c)
        {
            Constant _const = Constant();
            _const->parse(c);
            constants += ({ _const });
        }
    }

    string get_string()
    {
        return sprintf("%s%s", constants->get_string()*"\n",
            doc ? "\n\n" + doc->get_string() :  "");
    }
}

class DocGroupI
{
    inherit DocGroup;
    Doc doc;
    private array(Inherit) inherits = ({ });

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        if (node->get_first_element("doc"))
        {
            doc = Doc();
            doc->parse(node->get_first_element("doc"));
        }

        foreach (node->get_elements("inherit"), Parser.XML.Tree.SimpleNode i)
        {
            Inherit inh = Inherit();
            inh->parse(i);
            inherits += ({ inh });
        }
    }

    string get_string()
    {
        return sprintf("Inherit %s\n\n%s", inherits->get_string()*"\n   Inherit ",
            doc || "");
    }

    array(string) get_classnames(bool vimsyntax)
    {
        return inherits->get_classname(vimsyntax);
    }
}

class DocGroupD
{
    inherit DocGroup;
    private Doc doc;
    private Directive directive;

    void process_node(Parser.XML.Tree.SimpleNode node)
    {
        doc = Doc();
        doc->parse(node->get_first_element("doc"));
        directive = Directive();
        directive->parse(node->get_first_element("directive"));
        name = directive->get_name(0);
    }

    string get_string()
    {
        return sprintf("%s", doc ? "\n\n" + doc->get_string() : "");
    }
}

class Container
{
    inherit Base;
    protected Container parent;
    protected mapping(string:DocMethod) methods = ([ ]);
    protected mapping(string:Class) classes = ([ ]);
    protected mapping(string:Module) modules = ([ ]);
    protected array(DocGroupV) variables = ({ });
    protected array(DocGroupC) constants = ({ });
    protected array(DocGroupD) directives = ({ });
    protected array(DocGroupI) inherits = ({ });
    protected array(Container) _inherits = ({ });
    protected array(Container) _inherited = ({ });
    protected Doc doc;
    protected string path;

    void create(Container p)
    {
        parent = p;
    }

    protected void process_node(Parser.XML.Tree.SimpleNode node)
    {
        Parser.XML.Tree.SimpleNode d = node->get_first_element("doc");
        if (d)
        {
            if (!doc)
                doc = Doc();
            doc->parse(d);
        }

        foreach (node->get_elements("class"), Parser.XML.Tree.SimpleNode child)
        {
            mapping(string:mixed) attrs = child->get_attributes();
            string cname = attrs->name || "";
            if (has_index(classes, cname))
                classes[cname]->parse(child);
            else
            {
                classes[cname] = Class(this);
                classes[cname]->parse(child);
            }
        }

        foreach (node->get_elements("module"), Parser.XML.Tree.SimpleNode child)
        {
            mapping(string:mixed) attrs = child->get_attributes();
            string mname = attrs->name || "";
            if (has_index(modules, mname))
                modules[mname]->parse(child);
            else
            {
                modules[mname] = Module(this);
                modules[mname]->parse(child);
            }
        }

        foreach (node->get_elements("docgroup"), Parser.XML.Tree.SimpleNode node)
        {
            mapping(string:string) attrs = node->get_attributes();
            switch (attrs["homogen-type"])
            {
                case "method":
                    DocGroupM dgm = DocGroupM("");
                    dgm->parse(node);
                    foreach (dgm->docmethods, DocMethod dm)
                    {
                        if (has_index(methods, dm->get_name(0)))
                        {
                            methods[dm->get_name(0)]->methods = Array.uniq(
                                methods[dm->get_name(0)]->methods + dm->methods);

                            if (!methods[dm->get_name(0)]->doc)
                                methods[dm->get_name(0)]->doc = dm->doc;
                        }
                        else
                            methods[dm->get_name(0)] = dm;
                    };
                    break;

                case "variable":
                    DocGroupV dgv = DocGroupV();
                    dgv->parse(node);
                    variables += ({ dgv });
                break;

                case "constant":
                    DocGroupC dgc = DocGroupC();
                    dgc->parse(node);
                    constants += ({ dgc });
                    break;

                case "directive":
                    DocGroupD dgd = DocGroupD();
                    dgd->parse(node);
                    directives += ({ dgd });
                    break;

                case "inherit":
                    DocGroupI dgi = DocGroupI();
                    dgi->parse(node);
                    inherits += ({ dgi });
                    break;

                case "import":
                break;

                default:
                    werror("%s:%d: unknown homogen-type: %O\n", (__FILE__/"/")[-1],
                            __LINE__, attrs["homogen-type"]);
                    break;
            }
        }
    }

    string get_type() { return "Container"; }

    void save(string parent_dir)
    {
        string module_dir = ({ parent_dir, name })*"/";
        string this_path = ({ module_dir, "__this__" })*"/";
        Stdio.mkdirhier(this_path);

        if (!Stdio.exist(combine_path(this_path, "type")))
            Stdio.write_file(combine_path(this_path, "type"), get_type());

        if (string d = get_string())
        {
            Stdio.append_file(combine_path(this_path, "description"),
                string_to_utf8(d));
        }

        values(methods)->save(module_dir);
        values(classes)->save(module_dir);
        values(modules)->save(module_dir);

        if (sizeof(methods))
        {
            Stdio.write_file(combine_path(this_path, "methods"),
                get_table(Array.sort(values(methods)->get_name(1))[*]+"()"));
        }

        if (sizeof(classes))
        {
            Stdio.write_file(combine_path(this_path, "classes"),
                get_table(Array.sort(values(classes)->get_name(1))[*]+""));
        }

        if (sizeof(modules))
        {
            Stdio.write_file(combine_path(this_path, "modules"),
                get_table(Array.sort(values(modules)->get_name(1))[*]+""));
        }

    }

    string get_string()
    {
        string ret = "";
        if (sizeof(_inherits) || sizeof(_inherited))
        {
            ret += "Inheritance graph:\n";
            string prefix = "";
            string hline;
            foreach (_inherits, Container c)
            {
                ret += sprintf("%s*%s*\n", prefix, c->get_path());
                prefix += "  |  ";
                if (hline)
                    hline += "--+--";
                else
                    hline = "  +--";
            }
            ret += sprintf("%s%s\n", hline || "", get_path());
            prefix = replace(prefix, "|", " ") + "  |--";
            foreach (_inherited, Container c)
            {
                ret += sprintf("%s*%s*\n", prefix, c->get_path());
            }
            ret += line();
        }

        if (doc)
            ret += doc->get_string();

        if (sizeof(constants))
        {
            foreach (constants, DocGroupC c)
            {
                ret += sprintf("%sConstant %s\n%s\n", line(),
                        c->get_name(1), c->get_string());
            }
        }

        if (sizeof(directives))
        {
            foreach (directives, DocGroupD d)
            {
                ret += sprintf("%sDirective %s\n%s\n", line(),
                        d->get_name(1), d->get_string());
            }
        }

        if (sizeof(variables))
        {
            foreach (variables, DocGroupV v)
            {
                ret += sprintf("%sVariable %s\n%s\n", line(),
                        v->get_name(1), v->get_string());
            }
        }

        if (sizeof(inherits))
        {
            foreach (inherits, DocGroupI i)
            {
                ret += sprintf("%sInherit %s\n%s\n", line(),
                        i->get_name(0) || "", i->get_string() || "");
            }
        }

        return ret;
    }

    mapping(string:DocMethod) get_methods() { return methods; }

    void resolve_inheritance()
    {
        array(Container) all_modules = values(namespaces)->get_children()*({});
        array(string) paths = all_modules->get_path();
        foreach (inherits->get_classnames(0)*({}), string inheritance)
        {
            int pos = Array.search_array(paths, lambda(string current) {
                        if (has_value(inheritance, "."))
                        {
                            return has_value(current, inheritance);
                        }
                        else
                        {
                            return has_value(current/".", inheritance);
                        }
                    });

            if (pos != -1)
            {
                _inherits += ({ all_modules[pos] });
                methods = all_modules[pos]->get_methods() | methods;
                _inherits[-1]->add_inheritance(this);
            }
        }
    }

    void add_inheritance(Container i)
    {
        _inherited += ({ i });
    }

    string get_path()
    {
        if (!path)
            path = (parent ? parent->get_path()+"." : "") + (name||"");

        return path;
    }

    array(Container) get_children()
    {
        return values(modules) + values(classes)
            + values(modules)->get_children() + values(classes)->get_children();
    }
}

class Class
{
    inherit Container;

    string get_type() { return "class"; }

    string get_string()
    {
        return sprintf("Class %s%s%s%s%s\n", get_name(1), line(), ::get_string(),
            line(), get_table(Array.sort(values(methods)->get_name(1))[*]+"()"));
    }
}

class Module
{
    inherit Container;

    string get_type() { return "module"; }

    string get_string()
    {
        return sprintf("Module %s%s%s%s%s\n", get_name(1), line(), ::get_string(),
            line(), get_table(Array.sort(values(methods)->get_name(1))[*]+"()"));
    }
}

class Namespace
{
    inherit Container;

    private array(Container) children;

    string get_type() { return "namespace"; }

    string get_string()
    {
        return sprintf("Namespace %s%s%s%s%s\n", get_name(1), line(), ::get_string(),
            line(), get_table(Array.sort(values(methods)->get_name(1))[*]+"()"));
    }

    array(Container) get_children()
    {
        if (!children)
            children = Array.flatten(::get_children());

        return children;
    }
}

mapping(string:Namespace) namespaces = ([ ]);

void|int parse_node(Parser.XML.Tree.SimpleNode node)
{
    mapping(string:mixed) attrs = node->get_attributes();
    switch (node->get_any_name())
    {
        case "autodoc":
            node->iterate_children(parse_node);
        break;

        case "namespace":
            if (attrs->name)
            {
                Namespace namespace = namespaces[attrs->name]
                    || Namespace(UNDEFINED);
                namespace->parse(node);

                namespaces[attrs->name] = namespace;

            }
        break;

        default:
            string r = node->get_any_name();
            int t = node->get_node_type();

            if (!(<Parser.XML.Tree.XML_TEXT,
                Parser.XML.Tree.XML_HEADER>)[t])
                werror("Uknown high-level node(%O): %O\n", t, strlen(r) ? r : node);
        break;
    }
}

void recurse(string srcdir, string builddir, int root_ts, array(string) root)
{
    if (verbosity > 1)
        werror("Extracting from %s\n", srcdir);

    Stdio.Stat st;
    if (file_stat(srcdir+"/.noautodoc"))
        return;

    if (st = file_stat(srcdir+"/.autodoc"))
    {
        // Note .autodoc files are space-separated to allow for namespaces like
        //        "7.0::".
        root = (Stdio.read_file(srcdir+"/.autodoc")/"\n")[0]/" " - ({""});
        if (!sizeof(root) || !has_suffix(root[0], "::"))
        {
            if (sizeof(root) && has_value(root[0], "::"))
            {
                // Broken .autodoc file
                werror("Invalid syntax in %s.\n"
                        ":: Must be last in the token.\n",
                        srcdir + "/.autodoc");
                if (!flags & Tools.AutoDoc.FLAG_COMPAT)
                {
                    error("Invalid syntax in .autodoc file.\n");
                }
                array(string) a = root[0]/"::";
                root = ({ a[0] + "::" }) + a[1..] + root[1..];
            }
            else
            {
                // The default namespace is predef::
                root = ({ "predef::" }) + root;
            }
        }
        root_ts = st->mtime;
    }
    else if (st = file_stat(srcdir+"/.bmmlrc"))
    {
        if (Stdio.read_file(srcdir+"/.bmmlrc") == "prefix internal\n")
        {
            root = ({ "c::" });
        }
        root_ts = st->mtime;
    }


    if (!file_stat(srcdir))
    {
        if (!Stdio.is_dir(builddir))
            werror("Could not find directory %O.\n", srcdir);

        return;
    }

    // do not recurse into the build dir directory to avoid infinite loop
    // by building the autodoc of the autodoc and so on
    if (search(builddir, srcdir) == -1)
    {
        foreach (filter(get_dir(srcdir), has_suffix, ".cmod"), string fn)
        {
            Stdio.Stat stat = file_stat(srcdir + fn);
            if (!stat || !stat->isreg)
                continue;
            int mtime = stat->mtime;

            // Check for #cmod_include.
            multiset(string) checked = (<>);
            string data = Stdio.read_bytes(srcdir + fn);
            foreach (filter(data/"\n", has_prefix, "#"), string line)
            {
                if (sscanf(line, "#%*[ \t]cmod_include%*[ \t]\"%s\"", string inc) > 2)
                {
                    if (!checked[inc])
                    {
                        checked[inc] = 1;
                        stat = file_stat(combine_path(srcdir, inc));
                        if (stat && stat->isreg && stat->mtime > mtime)
                            mtime = stat->mtime;
                    }
                }
            }

            string target = fn[..<5] + ".c";
            stat = file_stat(srcdir + target);
            if (!stat || stat->mtime <= mtime)
            {
                // Regenerate the target.
                mixed err = catch {
                    Tools.Standalone.precompile()->
                    main(6, ({ "precompile.pike", "--api=max", "-w",
                                "-o", srcdir+target, srcdir+fn }));
                };
                if (err)
                {
                    // Something failed.
                    werror("Precompilation of %s to %s failed:\n"
                            "%s",
                            srcdir+fn, srcdir+target, describe_error(err));
                }
            }
        }
        foreach (get_dir(srcdir), string fn)
        {
            if (fn=="CVS")
                continue;

            if (fn[0]=='.')
                continue;

            if (fn[-1]=='~')
                continue;

            if (fn[0]=='#' && fn[-1]=='#')
                continue;

            Stdio.Stat stat = file_stat(srcdir+fn);

            if (!stat)
                continue;

            if (stat->isdir)
            {
                if (!file_stat(builddir+fn))
                    mkdir(builddir+fn);

                string mod_name = fn;
                sscanf(mod_name, "%s.pmod", mod_name);
                recurse(srcdir+fn+"/", builddir+fn+"/", root_ts, root + ({mod_name}));
                continue;
            }

            if (stat->size<1)
                continue;

            if (!has_suffix(fn, ".pike") && !has_suffix(fn, ".pike.in")
                && !has_suffix(fn, ".pmod") && !has_suffix(fn, ".pmod.in")
                && !has_suffix(fn, ".c") && !has_suffix(fn, ".cc")
                && !has_suffix(fn, ".m") && !has_suffix(fn, ".bmml")
                && has_value(fn, "."))
            {
                continue;
            }

            string res = extract(srcdir+fn, imgdir, builddir, root);
            if (!res)
            {
                if (!(flags & Tools.AutoDoc.FLAG_KEEP_GOING))
                    exit(1);

                res = "";
            }

            if (sizeof(res) && (res != "\n"))
            {
                // Validate the extracted XML.
                Parser.XML.Tree.SimpleRootNode root_node;
                mixed err = catch {
                    root_node = Parser.XML.Tree.simple_parse_input(res);
                };
                if (err)
                {
                    werror("Extractor generated broken XML for file %s:\n"
                            "%s",
                            builddir + fn + ".xml", describe_error(err));
                    if (flags & Tools.AutoDoc.FLAG_KEEP_GOING)
                        continue;

                    exit(1);
                }

                root_node->iterate_children(parse_node);
            }
        }
    }
}

string gather_data(string target)
{
    string data = "";
    foreach (get_dir(target), string name)
    {
        if (name == "__this__")
            continue;

        if (name == "pikedoc_index.txt")
            continue;

        string path = combine_path(target, name);
        if (name[<2..] != "txt" && Stdio.is_file(path))
            continue;

        data += sprintf("%s %s\n", Protocols.HTTP.uri_decode(name-".txt"),
            Stdio.is_dir(path)
            && combine_path(path, "__this__", "description") || path);

        if (Stdio.is_dir(path))
            data += gather_data(path);
    }

    return data;
}

int main(int n, array(string) args)
{
    string srcdir, targetdir = "./";
    string builddir = "/tmp/pikedoc_builddir/";
    imgdir = combine_path(builddir, "images/");

    array(string) root = ({"predef::"});

    int return_count;

    array(array(string|int|array(string))) opts = ({
        ({ "srcdir",     Getopt.HAS_ARG, "--srcdir" }),
        ({ "imgsrc",     Getopt.HAS_ARG, "--imgsrc" }),
        ({ "builddir",   Getopt.HAS_ARG, "--builddir" }),
        ({ "imgdir",     Getopt.NO_ARG,  "--imgdir" }),
        ({ "root",       Getopt.HAS_ARG, "--root" }),
        ({ "compat",     Getopt.NO_ARG,  "--compat" }),
        ({ "count",      Getopt.NO_ARG,  "--count" }),
        ({ "timestamp",  Getopt.HAS_ARG, "--source-timestamp" }),
        ({ "no-dynamic", Getopt.NO_ARG,  "--no-dynamic" }),
        ({ "keep-going", Getopt.NO_ARG,  "--keep-going" }),
        ({ "verbose",    Getopt.NO_ARG,  "-v,--verbose"/"," }),
        ({ "quiet",      Getopt.NO_ARG,  "-q,--quiet"/"," }),
        ({ "help",       Getopt.NO_ARG,  "-h,--help"/"," }),
        ({ "columns",    Getopt.HAS_ARG, "--columns" }),
        ({ "width",      Getopt.HAS_ARG, "--width" }),
        ({ "targetdir",  Getopt.HAS_ARG, "--targetdir" }),
    });

    foreach(Getopt.find_all_options(args, opts), array opt)
    {
        switch(opt[0])
        {
            case "srcdir":
                srcdir = combine_path(getcwd(), opt[1]);
                if(srcdir[-1]!='/') srcdir += "/";
                break;
            case "imgsrc":
                imgsrc = combine_path(getcwd(), opt[1]);
                break;
            case "builddir":
                builddir = combine_path(getcwd(), opt[1]);
                if(builddir[-1]!='/') builddir += "/";
                break;
            case "imgdir":
                imgdir = combine_path(getcwd(), opt[1]);
                if(imgdir[-1]!='/') imgdir += "/";
                break;
            case "compat":
                flags |= Tools.AutoDoc.FLAG_COMPAT;
                break;
            case "count":
                return_count = 1;
                break;
            case "no-dynamic":
                flags |= Tools.AutoDoc.FLAG_NO_DYNAMIC;
                break;
            case "keep-going":
                flags |= Tools.AutoDoc.FLAG_KEEP_GOING;
                break;
            case "root":
                root = opt[1]/".";
                break;
            case "quiet":
                flags = (flags & ~Tools.AutoDoc.FLAG_VERB_MASK)
                        |Tools.AutoDoc.FLAG_QUIET;
                break;
            case "verbose":
                verbosity = flags & Tools.AutoDoc.FLAG_VERB_MASK;
                if (verbosity < Tools.AutoDoc.FLAG_DEBUG)
                    verbosity++;
                flags = (flags & ~Tools.AutoDoc.FLAG_VERB_MASK)|verbosity;
                break;
            case "timestamp":
                // This is currently only used by the BMML handler.
                // It's used to convert /precompiled/foo module-references
                // to their corresponding module name as of this timestamp.
                source_timestamp = (int)opt[1];

                for (int i = sizeof(bmml_invalidation_times); i--;)
                {
                    if (bmml_invalidation_times[i] < source_timestamp)
                    {
                        bmml_invalidate_before = bmml_invalidation_times[i];
                        bmml_invalidate_after = bmml_invalidation_times[i+1];
                        break;
                    }
                }
                break;
            case "help":
                werror("Usage:\n"
                        "\tpike -x extract_autodoc [-q|--quiet] [-v|--verbose]\n"
                        "\t     [--compat] [--no-dynamic] [--keep-going]\n"
                        "\t     --srcdir=<srcdir>\n"
                        "\t     [--imgsrcdir=<imgsrcdir>] [--builddir=<builddir>]\n"
                        "\t     [--imgdir=<imgdir>] [--root=<module>]\n"
                        "\t     [file1 [... filen]]\n");
                return 0;
            case "columns":
                columns = (int)opt[1];
                break;
            case "width":
                width = (int)opt[1];
                break;
            case "targetdir":
                targetdir = combine_path(getcwd(), opt[1]);
                if(targetdir[-1]!='/') targetdir += "/";
                break;
        }
    }

    verbosity = flags & Tools.AutoDoc.FLAG_VERB_MASK;

    args = args[1..] - ({ 0 });

    Stdio.mkdirhier(targetdir);
    Stdio.mkdirhier(builddir);
    Stdio.mkdirhier(imgdir);

    if (srcdir)
        recurse(srcdir, builddir, 0, root);
    else if (sizeof(args))
    {
        foreach (args, string fn)
        {
            Stdio.Stat stat = file_stat(fn);
            Stdio.Stat dstat = file_stat(builddir+fn+".xml");

            // Build the xml file if it doesn't exist, if it is older than the
            // source file, or if the root has changed since the previous build.
            if (!dstat || dstat->mtime <= stat->mtime)
            {
                string res = extract(fn, imgdir, builddir, root);

                if (!res)
                {
                    if (flags & Tools.AutoDoc.FLAG_KEEP_GOING)
                        continue;

                    exit(1);
                }

                num_updated_files++;

                if (sizeof(res) && (res != "\n"))
                {
                    // Validate the extracted XML.
                    mixed err = catch {
                        Parser.XML.Tree.simple_parse_input(res);
                    };
                    if (err)
                    {
                        werror("Extractor generated broken XML for file %s:\n"
                                "%s",
                                builddir + fn + ".xml", describe_error(err));
                        rm(builddir+fn+".xml");
                        Stdio.write_file(builddir+fn+".brokenxml", res);
                        Stdio.write_file(builddir+fn+".xml.stamp",
                                (string)source_timestamp);
                        werror("Result saved as %s.\n", builddir + fn + ".brokenxml");
                        if (flags & Tools.AutoDoc.FLAG_KEEP_GOING)
                            continue;

                        exit(1);
                    }
                }

                Stdio.write_file(builddir+fn+".xml", res);
                Stdio.write_file(builddir+fn+".xml.stamp", (string)source_timestamp);
            }
        }
    }
    else {
        werror("No source directory or input files given.\n");
        return 1;
    }


    foreach (values(namespaces)->get_children(), array(Container) children)
    {
        foreach (children, Container child)
        {
            if (child)
                child->resolve_inheritance();
        }
    }

    values(namespaces)->save(targetdir);

    string data = gather_data(targetdir);
    string index = "";
    mapping(string:array(string)) tmp_index = ([ ]);

    foreach (data/"\n", string line)
    {
        if (!strlen(line))
            continue;

        array(string) splitted = line/" ";
        if (has_index(tmp_index, splitted[0]))
            tmp_index[splitted[0]] += ({ splitted[1] });
        else
            tmp_index[splitted[0]] = ({ splitted[1] });
    }

    foreach (tmp_index; string key; array(string) paths)
        index += sprintf("%s %s\n", key, paths*",");

    Stdio.write_file(combine_path(targetdir, "pikedoc_index.txt"), index);

    Stdio.recursive_rm(builddir);
    if (Stdio.exist(imgdir))
        Stdio.recursive_rm(imgdir);

    if (return_count)
        return num_updated_files;

    return 0;
}
