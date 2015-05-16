public: yes
tags: [c++, bison, flex, parsing]
summary: |
  How to use Bison with C++11 to parse ASTs into your preferred data
  structures while keeping the parser module as concise and simple as
  possible.

Feeding a Bison with tasty C++11 grAST!
=======================================

In this post I am going to explain how to write a parser in idiomatic C++
using Bison_ and Flex_. The parser outputs an AST (abstract syntax tree) in
simple C++ data structures. The main focus of this technique is to avoid
boilerplate code and repetition and to keep the parsing and semantic
analysis stages separate. The design principles are strongly influenced by
the `UNIX philosophy`_ and the `Zen of Python`_. This example also
demonstrates how to use location tracking in order to improve the usefulness
of error messages. If you are looking to get the most performance out of
your parser, however, this post is not for you.

For a live version of this code see my citip_ git repository.

.. _Bison: http://www.gnu.org/software/bison/manual/
.. _Flex: http://flex.sourceforge.net/
.. _UNIX philosophy: http://en.wikipedia.org/wiki/Unix_philosophy
.. _Zen of Python: https://www.python.org/dev/peps/pep-0020/
.. _citip: https://github.com/coldfix/Citip


A bit of context
~~~~~~~~~~~~~~~~

Recently, I forked a small tool to check if an inequality is a Shannon-type
inequality. I wanted to make a few minor modifications. However, the parser
component was written so poorly that it was nearly impossible to understand
let alone modify:

- Bison and Flex were used in the default mode in which all the arguments
  are communicated as global variables. This was not really a problem but
  being used to object oriented or functional design principles, it still
  pained me to see.

- The parser immediately transformed the input to an effective data format
  by computing parts of the input expressions and thus removing information
  that would be needed to later use the input in a different way.
  Furthermore, this had the effect of decreasing readability and mangling
  the semantic analysis with the lower level parsing stage.

- The aforementioned input transformation was implemented as a confusing
  state machine which I still haven't understood as of today.

- There was a Flex module that wasn't even used to break the textual input
  down into a stream of tokens but rather for some sort of weird and
  completely pointless preprocessing. This resulted in the original authors
  having to write ridiculous amounts of code to recognize identifiers in the
  Bison code.

- There were a number of additional abominations unrelated to the design
  principles of the parser itself.

At the time I did not know that Bison and Flex can also be used in a more
modern fashion and so I initially hesitated to do any fundamental
modifications. But later I decided to rewrite the entire component to keep
my mind at ease. This time I wanted the parser comply with some constraints:

- *Thread safety* — All state should be kept as local variables and
  communicated via function arguments and return values.

- *Modularity* — The parser should have only one purpose, and that is to
  parse the user input into equivalent C++ objects. Various computations
  can then be done in independent subsequent steps.

- *Simplicity* — In particular, do not keep one or more state variables
  that are used determine which code branch to use later on.

- *Composition* — Use Flex to break the input stream into tokens.

- You can add most of the remaining UNIX principles to this list. Almost
  all of them were heavily violated in some form or the other in the
  original program code.

I looked up a_ few_ examples_ on the web for using Bison with C++. None of
those I found completely satisfactory — which is why I'm writing this blog
post today.

.. _a: http://www.progtools.org/compilers/tutorials/cxx_and_bison/cxx_and_bison.html
.. _few: https://panthema.net/2007/flex-bison-cpp-example/
.. _examples: http://gnuu.org/2009/09/18/writing-your-own-toy-compiler/

Enough of this, let's see some actual code.


Tokenizer
~~~~~~~~~

Flex supports thread-safe interfaces (Flex jargon — *reentrant*) in plain C
as well as C++. Although dubbed experimental, I settled for the C++ API.
The advantage of the `Flex C++ API`_ over its `reentrant C counterpart`_ is
that it allows to use standard stream objects and cleans itself up
automatically. By default Flex generates the code for a class with a
superset of the following interface:

.. code-block:: c++

    class yyFlexLexer {
    public:
        yyFlexLexer(istream*, ostream*);
        int yylex();
    };

.. _Flex C++ API: http://flex.sourceforge.net/manual/Cxx.html
.. _reentrant C counterpart: http://flex.sourceforge.net/manual/Reentrant.html


In order to feed data back to Bison, we must provide a replacement for the
``yylex`` method that accepts parameters for value and location. The easiest
way to do this is to derive a scanner class that provides a method with the
desired signature. We do this in a header file called ``scanner.hpp``. The
important parts of this file are outlined below:

.. code-block:: c++

    #ifndef __SCANNER_HPP__INCLUDED__
    #define __SCANNER_HPP__INCLUDED__

    # undef yyFlexLexer
    # include <FlexLexer.h>
    # include "parser.hxx"

    // Tell flex which function to define
    # undef YY_DECL
    # define YY_DECL                                \
        int yy::scanner::lex(                       \
                yy::parser::semantic_type* yylval,  \
                yy::parser::location_type* yylloc)


    namespace yy
    {
        class scanner : public yyFlexLexer
        {
        public:
            explicit scanner(std::istream* in=0, std::ostream* out=0);

            int lex(parser::semantic_type* yylval,
                    parser::location_type* yylloc);
        };
    }

    #endif // include-guard

By the way, I use the extensions ``.hpp`` versus ``.hxx`` to distinguish
handcrafted header files from generated headers. Anologously, the extensions
``.cpp`` and ``.cxx`` are used for source files.

The tokenizer itself is defined in the file ``scanner.l`` which consists
of `three sections`_ separated by a ``%%``.

.. _three sections: http://flex.sourceforge.net/manual/Format.html

The first section can be used to set `Flex options`_. It can also contain
code blocks that will be inserted near the top of the generated ``.cxx``
file. This is useful to define convenience macros for the lexer actions in
the second section.

.. _Flex options: http://flex.sourceforge.net/manual/Scanner-Options.html

.. code-block:: c++

    %option     outfile="scanner.cxx"
    %option header-file="scanner.hxx"

    %option c++
    %option 8bit warn nodefault
    %option noyywrap

    %{
        #include <stdexcept>
        #include <cstdlib>
        #include "parser.hxx"
        #include "scanner.hpp"

        // utility macros to simplify the actions
        #define YIELD_TOKEN(tok, val, type)                 \
                        yylval->build<type>(val);           \
                        return yy::parser::token::T_##tok;

        #define YY_TXT                  std::string(yytext, yyleng)
        #define YY_NUM                  std::atof(yytext)

        #define INT_TOKEN(tok, val)     YIELD_TOKEN(tok, val, int)
        #define NUM_TOKEN(tok)          YIELD_TOKEN(tok, YY_NUM, double)
        #define STR_TOKEN(tok)          YIELD_TOKEN(tok, YY_TXT, std::string)
        #define LITERAL                 return yytext[0];

        // before executing an action, set the length of the location from
        // the length of the matched pattern:
        #define YY_USER_ACTION          yylloc->columns(yyleng);
    %}

    %%

The second section defines what the scanner actually does. You can ignore
the details of the rules defined here — as these will be specific to your
language. See the Flex documentation on patterns_ for more details. In my
application, this section looks as follows:

.. _patterns: http://flex.sourceforge.net/manual/Patterns.html

.. code-block:: c++

    %{
        // before matching any pattern, update the the current location
        yylloc->step();
    %}

    I/\(                        LITERAL
    H/\(                        LITERAL

    [[:alpha:]][[:alnum:]_]*    STR_TOKEN(NAME)

    [[:digit:]]+                NUM_TOKEN(NUM)
    [[:digit:]]*\.[[:digit:]]+  NUM_TOKEN(NUM)

    \+                          INT_TOKEN(SIGN, ast::SIGN_PLUS)
    \-                          INT_TOKEN(SIGN, ast::SIGN_MINUS)

    ==?                         INT_TOKEN(REL, ast::REL_EQ)
    \<=                         INT_TOKEN(REL, ast::REL_LE)
    \>=                         INT_TOKEN(REL, ast::REL_GE)

    #.*                         {/* eat comments */}
    [ \t]                       {/* eat whitespace */}

    \n                          yylloc->lines(1); LITERAL

                                /* forward everything else, even invalid
                                 * tokens - making use of bison's automatic
                                 * error messages */
    .                           LITERAL

    %%


The final section can contain arbitrary code. This is the perfect place to
implement methods of our scanner class.

.. code-block:: c++

    yy::scanner::scanner(std::istream* in, std::ostream* out)
        : yyFlexLexer(in, out)
    {
    }

    // Flex generates the code for `yy::scanner::lex` (see YY_DECL).

    // This must be defined manually to prevent linker errors:
    int yyFlexLexer::yylex()
    {
        throw std::logic_error(
            "The yylex() exists for technical reasons and must not be used.");
    }



AST
~~~

Before we dive into the parser, let's have a short look at our AST. Again,
you can safely ignore the details. Just note that I prefer to work with
simple structs and standard library containers as opposed to classes with
virtual methods. This means that I get automatic support for initializer
lists and that my data is easy to keep on the stack without requiring
pointer semantics. If you somewhere do need polymorphic behaviour, I
recommend to a smart pointer such as `std::shared_ptr`_.

.. _`std::shared_ptr`: http://en.cppreference.com/w/cpp/memory/shared_ptr

These are the contents of the file ``ast.hpp``:

.. code-block:: c++

    #ifndef __AST_HPP__INCLUDED__
    #define __AST_HPP__INCLUDED__

    # include <string>
    # include <vector>

    namespace ast
    {

        enum {
            SIGN_PLUS,
            SIGN_MINUS
        };

        enum {
            REL_EQ,
            REL_LE,
            REL_GE
        };

        typedef std::vector<std::string>    VarList;
        typedef std::vector<VarList>        VarCore;

        struct Quantity
        {
            VarCore parts;
            VarList cond;
        };

        struct Term
        {
            double coefficient;
            Quantity quantity;

            inline Term& flip_sign(int s)
            {
                if (s == SIGN_MINUS) {
                    coefficient = -coefficient;
                }
                return *this;
            }
        };

        typedef std::vector<Term> Expression;

        struct Relation {
            Expression left;
            int relation;
            Expression right;
        };

        typedef VarCore MutualIndependence;
        typedef VarCore MarkovChain;

        struct FunctionOf {
            VarList function, of;
        };

    }

    #endif // include-guard


Parser
~~~~~~

Bison too supports thread-safe interfaces (the Bison term being *pure*) in
both C++ as well as plain C. The main advantage of the `Bison C++ API`_
over `pure C parsers`_ is that it allows to store the result of actions in
a variant_ instead of a union. Apart from simplifying the access notation,
this also means that even non-POD objects such as ``std::vector`` can be
stored on the stack without having to worry about cleanup. We will set up
Bison to generate a class with the following interface:

.. _Bison C++ API: http://www.gnu.org/software/bison/manual/bison.html#C_002b_002b-Parsers
.. _pure C parsers: http://www.gnu.org/software/bison/manual/bison.html#Pure-Decl
.. _variant: http://www.gnu.org/software/bison/manual/bison.html#C_002b_002b-Variants

.. code-block:: c++

    namespace yy {
        class parser {
        public:
            parser(yy::scanner*, ParserCallback*);
            int parse();
        };
    }

The callback is a simple interface to return results. The scanner argument
is used to retrieve a stream of tokens by calling its ``lex`` method
repeatedly.

The Bison parser is defined in the file ``bison.y``. This file is
structured similar to the Flex file discussed above: It has three sections
separated by ``%%``. The first section has multiple purposes. We start by
setting `parser options`_:

.. _parser options: http://www.gnu.org/software/bison/manual/bison.html#Declarations

.. code-block:: c++

    %output  "parser.cxx"
    %defines "parser.hxx"

    /* C++ parser interface */
    %skeleton "lalr1.cc"
    %require  "3.0"

    /* add parser members (scanner, cb) and yylex parameters (loc, scanner) */
    %parse-param  {yy::scanner* scanner} {ParserCallback* cb}
    %locations

    /* increase usefulness of error messages */
    %define parse.error verbose

    /* assert correct cleanup of semantic value objects */
    %define parse.assert

    %define api.value.type variant
    %define api.token.prefix {T_}

Note that I omit the ``%define api.token.constructor`` directive which
changes the expected signature of the ``yylex`` function to return the
token value and location. On the one hand, this can be considered cleaner
than passing the data back through a function argument — but it also
changes the token class type from integer to something else. This means
that it is no longer possible to match for plain ASCII characters in the
syntax rules below.

The next step is to define tokens and semantic value types, i.e. associate
the value of rules with data structures of our AST:

.. code-block:: c++

    %token                  END     0   "end of file"

    %token <std::string>    NAME
    %token <double>         NUM
    %token <int>            SIGN
                            REL

    %type <ast::Relation>               inform_inequ
    %type <ast::VarCore>                mutual_indep
    %type <ast::VarCore>                markov_chain
    %type <ast::FunctionOf>             determ_depen
    %type <ast::Expression>             inform_expr
    %type <ast::Term>                   inform_term
    %type <ast::Quantity>               inform_quant
    %type <ast::Quantity>               entropy
    %type <ast::Quantity>               mutual_inf
    %type <ast::VarList>                var_list
    %type <ast::VarCore>                mut_inf_core;

    %start statement


We also need this section to define code sections that will be prepended to
the generated source file and/or header file:

.. code-block:: c++

    /* inserted near top of header + source file */
    %code requires {
        #include <stdexcept>
        #include <string>

        #include "ast.hpp"
        #include "location.hh"

        namespace yy {
            class scanner;
        };

        // results
        struct ParserCallback {
            virtual void relation(ast::Relation) = 0;
            virtual void markov_chain(ast::MarkovChain) = 0;
            virtual void mutual_independence(ast::MutualIndependence) = 0;
            virtual void function_of(ast::FunctionOf) = 0;
        };

        void parse(const std::vector<std::string>&, ParserCallback*);
    }

    /* inserted near top of source file */
    %code {
        #include <iostream>     // cerr, endl
        #include <utility>      // move
        #include <string>
        #include <sstream>

        #include "scanner.hpp"

        using std::move;

        #ifdef  yylex
        # undef yylex
        #endif
        #define yylex scanner->lex

        // utility function to append a list element to a std::vector
        template <class T, class V>
        T&& enlist(T& t, V& v)
        {
            t.push_back(move(v));
            return move(t);
        }
    }

    %%

The second section contains our actual language specification. Most of it
should be easy to grasp. The thing to note here is the use of initializer
lists as a clean syntax to store values into our AST data structures. The
simplicity of the grammar actions show the true power of using simple AST
data types.

.. code-block:: c++

        /* deliver output */

    statement    : %empty           { /* allow empty (or pure comment) lines */ }
                 | inform_inequ     { cb->relation(move($1)); }
                 | mutual_indep     { cb->mutual_independence(move($1)); }
                 | markov_chain     { cb->markov_chain(move($1)); }
                 | determ_depen     { cb->function_of(move($1)); }
                 ;

        /* statements */

    inform_inequ : inform_expr REL inform_expr       { $$ = {$1, $2, $3}; }
                 ;

    markov_chain : markov_chain '/' var_list               { $$ = enlist($1, $3); }
                 |     var_list '/' var_list '/' var_list  { $$ = {$1, $3, $5}; }
                 ;

    mutual_indep : mutual_indep '.' var_list         { $$ = enlist($1, $3); }
                 |     var_list '.' var_list         { $$ = {$1, $3}; }
                 ;

    determ_depen : var_list ':' var_list             { $$ = {$1, $3}; }
                 ;

        /* building blocks */

    inform_expr  : inform_expr SIGN inform_term     { $$ = enlist($1, $3.flip_sign($2)); }
                 |             SIGN inform_term     { $$ = {{$2.flip_sign($1)}}; }
                 |                  inform_term     { $$ = {{$1}}; }
                 ;

    inform_term  : NUM inform_quant                 { $$ = {$1, $2}; }
                 |     inform_quant                 { $$ = { 1, $1}; }
                 | NUM                              { $$ = {$1}; }
                 ;

    inform_quant : entropy                          { $$ = $1; }
                 | mutual_inf                       { $$ = $1; }
                 ;

    entropy      : 'H' '(' var_list              ')'      { $$ = {{$3}}; }
                 | 'H' '(' var_list '|' var_list ')'      { $$ = {{$3}, $5}; }
                 ;

    mutual_inf   : 'I' '(' mut_inf_core              ')'  { $$ = {{$3}}; }
                 | 'I' '(' mut_inf_core '|' var_list ')'  { $$ = {{$3}, $5}; }
                 ;

    mut_inf_core :  mut_inf_core colon var_list     { $$ = enlist($1, $3); }
                 |      var_list colon var_list     { $$ = {$1, $3}; }
                 ;

    colon        : ':'
                 | ';'
                 ;

    var_list     : var_list ',' NAME                { $$ = enlist($1, $3); }
                 |              NAME                { $$ = {$1}; }
                 ;

    %%

I should mention that this doesn't have nice performance characteristics.
If you care about that it should be possible to use ``std::move()`` to move
the data instead of copying it at each assignment. In my program, I decided
that this wasn't worth the sacrafice of conciseness.

We are almost done now. As with flex, the final section is simply a code
section that will be appended literally to the generated source. It is the
right place to implement additional methods.

.. code-block:: c++

    void yy::parser::error(const parser::location_type& l, const std::string& m)
    {
        throw yy::parser::syntax_error(l, m);
    }

    // Example how to use the parser to parse a vector of lines:
    void parse(const std::vector<std::string>& exprs, ParserCallback* out)
    {
        for (int row = 0; row < exprs.size(); ++row) {
            const std::string& line = exprs[row];
            std::istringstream in(line);
            yy::scanner scanner(&in);
            yy::parser parser(&scanner, out);
            try {
                int result = parser.parse();
                if (result != 0) {
                    // Not sure if this can even happen
                    throw std::runtime_error("Unknown parsing error");
                }
            }
            catch (yy::parser::syntax_error& e) {
                // improve error messages by adding location information:
                int col = e.location.begin.column;
                int len = 1 + e.location.end.column - col;
                // TODO: The reported location is not entirely satisfying. Any
                // chances for improvement?
                std::ostringstream msg;
                msg << e.what() << "\n"
                    << "in row " << row << " col " << col << ":\n\n"
                    << "    " << line << "\n",
                    << "    " << std::string(col-1, ' ') << std::string(len, '^'));
                throw yy::parser::syntax_error(e.location, msg.str());
            }
        }
    }

All that remains to do now is to implement ``ParserCallback`` handlers and
the actual user code.

When compiling your program with g++, don't forget to add the
``-std=c++11`` option, i.e.:

.. code-block:: bash

    flex scanner.l
    bison parser.y
    g++ scanner.cxx -std=c++11
    g++ parser.cxx -std=c++11


Conclusion
~~~~~~~~~~

Even though Flex and Bison are extremely old tools that may seem quirky at
first, their widespread availability makes them the tool of choice for many
applications.

Although, I'm still not *entirely* satisfied in every aspect, the result is
much better than what could have been achieved with any of the other C++
parser generators I considered when looking for alternatives.

This shows that both tools are indeed carefully designed, adapt well and
can even become easier to use in the advent of new languages features.
