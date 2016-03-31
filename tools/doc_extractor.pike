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

string line(void|int width)
{
    return sprintf("\n%'-'" + (width || 80) + "s\n", "");
}

class Base
{
    protected string name;
    protected mapping(string:string) attributes;
    protected Parser.XML.Tree.SimpleNode self;

    string get_string() { return "Base"; }

    void create(Parser.XML.Tree.SimpleNode node, void|bool no_parse)
    {
        self = node;
        attributes = self->get_attributes() || ([ ]);
        name = attributes->name;
        if (!no_parse)
            parse();
    }

    void parse();

    string get_name() { return name; }

    mixed cast(string t)
    {
        return get_string();
    }

    string _sprintf()
    {
        return get_string();
    }
}

class Types
{
    inherit Base;
    private array(string) types;

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

    void parse()
    {
        Parser.XML.Tree.SimpleNode child = self->get_first_element();
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

class Value
{
    inherit Base;
    private string value;

    void parse()
    {
        value = (string)self->value_of_node();
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

    void parse()
    {
        if (Parser.XML.Tree.SimpleNode v = self->get_first_element("value"))
            value = Value(v);
        else
            types = Types(self->get_first_element("type"));
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

    void parse()
    {
        Parser.XML.Tree.SimpleNode argument_nodes =
            self->get_first_element("arguments");

        foreach (argument_nodes->get_elements("argument"),
            Parser.XML.Tree.SimpleNode child)
        {
            args += ({ Argument(child) });
        }

        returns = Types(self->get_first_element("returntype"));
    }

    string get_string()
    {
        return sprintf("%s %s(%s)", returns, name, args->get_string()*", ");
    }
}

class Variable
{
    inherit Base;

    private Types types;

    void parse()
    {
        types = Types(self);
    }

    string get_string()
    {
        return sprintf("%s", types);
    }
}

class Constant
{
    inherit Base;

    void parse() {}

    string get_string()
    {
        return sprintf("%s", name);
    }
}

class TextNode
{
    protected string text = "";
    protected Parser.XML.Tree.SimpleNode self;

    void create(Parser.XML.Tree.SimpleNode node)
    {
        self = node;

        if (self->get_node_type() == Parser.XML.Tree.XML_TEXT)
            text = self->value_of_node();
        else
        {
            foreach (self->get_children(), Parser.XML.Tree.SimpleNode c)
                text += TextNode(c)->get_string();
        }
    }

    string get_string()
    {
        if (self->get_any_name() == "p")
        {
            string ret = "";
            foreach (text/"\n", string line)
            {
                ret += sprintf("\n    %s", String.trim_all_whites(line));
            }

            return sprintf("\n%s\n", ret);
        }

        return text;
    }
}

class Group
{
    inherit Base;
    protected string type;
    protected string text;

    string get_type() { return type; }

    void parse()
    {
        foreach (self->get_elements(), Parser.XML.Tree.SimpleNode e)
        {
            string ename = e->get_any_name();
            if (ename == "text")
                text = TextNode(e)->get_string();
            else
            {
                type = ename;
                mapping(string:string) attrs = e->get_attributes();
                name = attrs->name || UNDEFINED;
            }
        }

        if (!text)
            text = "// Missing description\n";
    }

    string get_string() { return text; }
}

class Doc
{
    inherit Base;
    private string description;
    private array(Group) params = ({ });
    private array(Group) notes = ({ });
    private array(Group) returns = ({ });
    private array(Group) seealsos = ({ });

    void parse()
    {
        Parser.XML.Tree.SimpleNode text = self->get_first_element("text");
        if (text)
            description = TextNode(text)->get_string();

        foreach (self->get_elements("group"), Parser.XML.Tree.SimpleNode g)
        {
            Group group = Group(g);
            switch (group->get_type())
            {
                case "param":
                    params += ({ group });
                break;
                case "note":
                    notes += ({ group });
                break;
                case "returns":
                    returns += ({ group });
                break;
                case "seealso":
                    seealsos += ({ group });
                break;
            }
        }
    }

    string get_string()
    {
        string ret = "";
        if (description)
            ret = sprintf("Description%s", description);

        if (sizeof(params))
        {
            foreach (params, Group g)
            {
                ret += sprintf("Parameter %s%s",
                        g->get_name(), g->get_string());
            }
        }

        if (sizeof(returns))
        {
            foreach (returns, Group g)
                ret += sprintf("Returns%s", g->get_string());
        }

        if (sizeof(notes))
        {
            foreach (notes, Group g)
                ret += sprintf("Note%s", g->get_string());
        }

        if (sizeof(seealsos))
            ret += sprintf("See also%s", seealsos->get_string()*", ");

        return ret;
    }
}

class DocGroup
{
    inherit Base;
    protected string path;
    protected string parent_path;
    protected string filename;

    void create(Parser.XML.Tree.SimpleNode node, string _parent_path)
    {
        ::create(node, true);
        name = attributes["homogen-name"];
        parent_path = _parent_path;
        if (name)
        {
            path = ({ parent_path, Protocols.HTTP.uri_encode(name) })*"/";
            filename = path + ".txt";
        }
        parse();
    }

    void parse();

    protected void save()
    {
        if (Stdio.exist(filename))
            Stdio.append_file(filename, ({ line(), get_string() })*"\n");
        else
            Stdio.write_file(filename, get_string());
    }
}

class DocGroupM
{
    inherit DocGroup;
    private Doc doc;
    private array(Method) methods = ({ });

    void parse()
    {
        doc = Doc(self->get_first_element("doc"));
        foreach (self->get_elements("method"), Parser.XML.Tree.SimpleNode m)
            methods += ({ Method(m) });
        save();
    }

    string get_string(void|Method m)
    {
        string local_name = m && m->get_name() || name;
        return sprintf("Method %s\n\n    %s\n\n%s", local_name,
                methods->get_string()*"\n    ", doc);
    }

    string get_name()
    {
        if (name)
            return name;
        else
            return methods->get_name()*"\n";
    }

    protected void save()
    {
        if (name)
        {
            if (Stdio.exist(filename))
                Stdio.append_file(filename, ({ line(), string_to_utf8(get_string()) })*"\n");
            else
                Stdio.write_file(filename, string_to_utf8(get_string()));
        }
        else
        {
            foreach (methods, Method m)
            {
                string path = ({ parent_path,
                    Protocols.HTTP.uri_encode(m->get_name()) })*"/";

                string filename = path + ".txt";

                if (Stdio.exist(filename))
                {
                    Stdio.append_file(filename,
                        ({ line(), string_to_utf8(get_string(m)) })*"\n");
                }
                else
                    Stdio.write_file(filename, string_to_utf8(get_string(m)));
            }
        }
    }
}

class DocGroupV
{
    inherit DocGroup;
    private Doc doc;
    private Variable variable;

    void parse()
    {
        doc = Doc(self->get_first_element("doc"));
        variable = Variable(self->get_first_element("variable"));
    }

    string get_string()
    {
        return sprintf("Variable %s\n\n%s", variable, doc);
    }
}

class DocGroupC
{
    inherit DocGroup;
    Doc doc;
    private array(Constant) constants = ({ });

    void parse()
    {
        if (self->get_first_element("doc"))
            doc = Doc(self->get_first_element("doc"));

        foreach (self->get_elements("constant"), Parser.XML.Tree.SimpleNode c)
            constants += ({ Constant(c) });
    }

    string get_string()
    {
        return sprintf("    Constant %s\n\n%s", constants->get_string()*"\n   Constant ", doc || "");
    }
}

class Container
{
    inherit Base;
    protected string path;
    protected string this_path;
    protected array(string) methods = ({ });
    protected array(string) classes = ({ });
    protected array(string) modules = ({ });
    protected array(DocGroupV) variables = ({ });
    protected array(DocGroupC) constants = ({ });
    protected Doc doc;

    void create(Parser.XML.Tree.SimpleNode node, string parent_path)
    {
        ::create(node, true);
        path = ({ parent_path, name })*"/";
        this_path = ({ path, "__this__" })*"/";
        Stdio.mkdirhier(this_path);
        parse();
        save();
    }

    void parse()
    {
        Parser.XML.Tree.SimpleNode d = self->get_first_element("doc");
        if (d)
            doc = Doc(d);

        foreach (self->get_elements("class"), Parser.XML.Tree.SimpleNode child)
            classes += ({ Class(child, path)->get_name() });

        foreach (self->get_elements("module"), Parser.XML.Tree.SimpleNode child)
            modules += ({ Module(child, path)->get_name() });

        foreach (self->get_elements("docgroup"), Parser.XML.Tree.SimpleNode node)
        {
            mapping(string:string) attrs = node->get_attributes();
            switch (attrs["homogen-type"])
            {
                case "method":
                    methods += ({ DocGroupM(node, path)->get_name() });
                break;

                case "variable":
                    variables += ({ DocGroupV(node, path) });
                break;

                case "constant":
                    constants += ({ DocGroupC(node, path) });
                break;

                default:
                    // FIXME: (grodzik) debug print - remove me
                    werror("grodzik:%s:%d: attrs[\"homogen-type\"]: %O\n", (__FILE__/"/")[-1], __LINE__, attrs["homogen-type"]);
            }
        }
    }

    array(string) get_list(string file, array(string) list)
    {
        if (Stdio.exist(file))
            list += (Stdio.read_file(file)/"\n");

        array(string) ret = ({ });
        foreach (list; int i; string v)
        {
            v = String.trim_all_whites(v);
            if (strlen(v))
                ret += ({ v });
        }

        return Array.uniq(Array.sort_array(ret));
    }

    string get_type() { return "Container"; }

    void save()
    {
        if (!Stdio.exist(combine_path(this_path, "type")))
            Stdio.write_file(combine_path(this_path, "type"), get_type());

        if (string d = get_string())
        {
            Stdio.append_file(combine_path(this_path, "description"),
                    sprintf("%s\n\n%s\n\n%s\n", doc || "", line(), d));
        }

        mapping(string:array(string)) lists = ([
            "modules": modules,
            "classes": classes,
            "methods": methods
        ]);

        foreach (lists; string key; array(string) list)
        {
            if (sizeof(list))
            {
                string file = combine_path(this_path, key);
                list = get_list(file, list);

                Stdio.write_file(file,sprintf("    %s\n", list*"\n    "));
            }
        }
    }

    string get_string()
    {
        string ret = "";
        if (doc)
            ret = doc->get_string();

        if (sizeof(constants))
        {
            foreach (constants, DocGroupC c)
            {
                ret += sprintf("\nConstant %s\n%s\n",
                        c->get_name(), c->get_string());
            }
        }

        if (sizeof(variables))
        {
            foreach (variables, DocGroupV v)
            {
                ret += sprintf("\nVariable %s\n%s\n",
                        v->get_name(), v->get_string());
            }
        }

        return ret;
    }
}

class Class
{
    inherit Container;

    string get_type() { return "class"; }

    string get_string()
    {
        if (doc)
            return sprintf("Class %s\n\n%s\n", name, doc);
    }
}

class Module
{
    inherit Container;

    string get_type() { return "module"; }

    string get_string()
    {
        if (doc)
            return sprintf("Module %s\n\n%s\n", name, doc);
    }
}

class Namespace
{
    inherit Container;

    string get_type() { return "namespace"; }

    string get_string()
    {
        if (doc)
            return sprintf("Namespace %s\n\n%s\n", name, doc);
    }
}

void|int parse_node(Parser.XML.Tree.SimpleNode node, string path)
{
    mapping(string:mixed) attrs = node->get_attributes();
    switch (node->get_any_name())
    {
        case "autodoc":
            node->iterate_children(parse_node, path);
        break;

        case "namespace":
            if (attrs->name)
                Namespace namespace = Namespace(node, path);
        break;

        default:
            string r = node->get_any_name();
            if (strlen(r))
                werror("grodzik: %s\n", r);
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

    foreach (get_dir(builddir), string fn)
    {
        if ((fn != ".cache.xml") && has_suffix(fn, ".xml"))
        {
            if (!Stdio.is_file(srcdir + fn[..<4]))
            {
                if (verbosity > 0)
                    werror("The file %O is no more.\n", srcdir + fn[..<4]);

                num_updated_files++;
                rm(builddir + fn);
                rm(builddir + fn[..<4] + ".brokenxml");
                rm(builddir + fn + ".stamp");
                rm(builddir + ".cache.xml.stamp");
            }
            else if (source_timestamp && (source_timestamp < 950000000)
                && (sizeof(fn/".") == 2))
            {
                // BMML.
                int old_ts = (int)Stdio.read_bytes(builddir + fn + ".stamp");
                if ((old_ts < bmml_invalidate_before)
                    || (old_ts >= bmml_invalidate_after))
                {
                    // BMML file that may have changed at this time.
                    if (verbosity > 1)
                        werror("Forcing reextraction of %s.\n", srcdir + fn[..<4]);

                    rm(builddir + fn + ".stamp");
                }
            }
        }
        else if (Stdio.is_dir(builddir + fn) && !Stdio.is_dir(srcdir + fn))
        {
            // Recurse and clean away old obsolete files.
            recurse(srcdir + fn + "/", builddir + fn + "/", root_ts, root);
            rm(builddir + fn + "/.cache.xml.stamp");
            rm(builddir + fn + "/.cache.xml");
            // Try deleting the directory.
            rm(builddir + fn);
            rm(builddir + ".cache.xml.stamp");
        }
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
                    rm(srcdir+target);
                    rm(builddir+target+".xml");
                    rm(builddir+target+".xml.stamp");
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

            Stdio.Stat dstat = file_stat(builddir+fn+".xml")
                                && file_stat(builddir+fn+".xml.stamp");

            // Build the xml file if it doesn't exist, if it is older than the
            // source file, or if the root has changed since the previous build.
            if (!dstat || dstat->mtime <= stat->mtime || dstat->mtime <= root_ts)
            {
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

                    root_node->iterate_children(parse_node, builddir);
                }
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
    string srcdir, builddir = "./";
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
        }
    }

    verbosity = flags & Tools.AutoDoc.FLAG_VERB_MASK;

    args = args[1..] - ({ 0 });

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

    string data = gather_data(builddir);
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

    Stdio.write_file(combine_path(builddir, "index.txt"), index);

    if (return_count)
        return num_updated_files;

    return 0;
}
