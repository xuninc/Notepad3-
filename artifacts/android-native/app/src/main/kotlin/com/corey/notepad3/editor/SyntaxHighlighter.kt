package com.corey.notepad3.editor

import com.corey.notepad3.models.DocumentLanguage

enum class HighlightCategory {
    KEYWORD,
    COMMENT,
    STRING,
    NUMBER,
}

data class HighlightRange(
    val start: Int,
    val end: Int,
    val category: HighlightCategory,
)

object SyntaxHighlighter {
    const val DEFAULT_MAX_TEXT_LENGTH: Int = 200_000

    fun supports(language: DocumentLanguage): Boolean =
        language != DocumentLanguage.PLAIN && language != DocumentLanguage.MARKDOWN

    fun plan(
        text: String,
        language: DocumentLanguage,
        maxTextLength: Int = DEFAULT_MAX_TEXT_LENGTH,
    ): List<HighlightRange> {
        if (text.isEmpty() || text.length > maxTextLength || !supports(language)) {
            return emptyList()
        }

        val claimed = BooleanArray(text.length)
        val ranges = mutableListOf<HighlightRange>()
        val rules = rulesFor(language)

        claimMatches(text, Regexes.string, HighlightCategory.STRING, claimed, ranges)
        if (rules.supportsBlockComments) {
            claimMatches(text, Regexes.blockComment, HighlightCategory.COMMENT, claimed, ranges)
        }
        claimLineComments(text, rules.commentPrefixes, claimed, ranges)
        claimMatches(text, Regexes.number, HighlightCategory.NUMBER, claimed, ranges)
        claimKeywords(text, rules, claimed, ranges)

        return ranges.sortedWith(compareBy<HighlightRange> { it.start }.thenBy { it.end })
    }

    private fun claimMatches(
        text: String,
        regex: Regex,
        category: HighlightCategory,
        claimed: BooleanArray,
        ranges: MutableList<HighlightRange>,
    ) {
        regex.findAll(text).forEach { match ->
            claim(match.range.first, match.range.last + 1, category, claimed, ranges)
        }
    }

    private fun claimLineComments(
        text: String,
        prefixes: List<String>,
        claimed: BooleanArray,
        ranges: MutableList<HighlightRange>,
    ) {
        if (prefixes.isEmpty()) return

        var index = 0
        while (index < text.length) {
            val prefix = prefixes.firstOrNull { text.startsWith(it, index) }
            if (prefix == null || claimed[index]) {
                index += 1
                continue
            }

            val end = text.indexOf('\n', startIndex = index).takeIf { it >= 0 } ?: text.length
            claim(index, end, HighlightCategory.COMMENT, claimed, ranges)
            index = end
        }
    }

    private fun claimKeywords(
        text: String,
        rules: LanguageRules,
        claimed: BooleanArray,
        ranges: MutableList<HighlightRange>,
    ) {
        if (rules.keywords.isEmpty()) return

        Regexes.identifier.findAll(text).forEach { match ->
            val start = match.range.first
            val end = match.range.last + 1
            if (isClaimed(start, end, claimed)) return@forEach

            val word = match.value
            val lookup = if (rules.caseInsensitiveKeywords) word.lowercase() else word
            if (rules.keywords.contains(lookup)) {
                claim(start, end, HighlightCategory.KEYWORD, claimed, ranges)
            }
        }
    }

    private fun claim(
        start: Int,
        end: Int,
        category: HighlightCategory,
        claimed: BooleanArray,
        ranges: MutableList<HighlightRange>,
    ) {
        if (start < 0 || end <= start || end > claimed.size || isClaimed(start, end, claimed)) return

        for (index in start until end) {
            claimed[index] = true
        }
        ranges += HighlightRange(start, end, category)
    }

    private fun isClaimed(start: Int, end: Int, claimed: BooleanArray): Boolean =
        (start until end).any { claimed[it] }

    private object Regexes {
        val blockComment = Regex("/\\*[\\s\\S]*?\\*/")
        val string = Regex("`(?:\\\\.|[^`\\\\])*`|\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'")
        val number = Regex("\\b(?:0x[0-9a-fA-F]+|\\d+(?:\\.\\d+)?)\\b")
        val identifier = Regex("\\b[A-Za-z_][A-Za-z0-9_]*\\b")
    }

    private data class LanguageRules(
        val keywords: Set<String>,
        val commentPrefixes: List<String>,
        val supportsBlockComments: Boolean,
        val caseInsensitiveKeywords: Boolean,
    )

    private fun rulesFor(language: DocumentLanguage): LanguageRules =
        LanguageRules(
            keywords = keywordsFor(language),
            commentPrefixes = commentPrefixesFor(language),
            supportsBlockComments = supportsBlockComments(language),
            caseInsensitiveKeywords = caseInsensitiveKeywords(language),
        )

    private fun commentPrefixesFor(language: DocumentLanguage): List<String> =
        when (language) {
            DocumentLanguage.ASSEMBLY -> listOf(";")
            DocumentLanguage.PYTHON,
            DocumentLanguage.RUBY,
            DocumentLanguage.SHELL,
            DocumentLanguage.POWERSHELL,
            DocumentLanguage.YAML,
            DocumentLanguage.TOML,
            DocumentLanguage.DOCKERFILE,
            -> listOf("#")
            DocumentLanguage.INI -> listOf(";", "#")
            DocumentLanguage.SQL -> listOf("--")
            DocumentLanguage.HTML,
            DocumentLanguage.XML,
            -> listOf("<!--")
            DocumentLanguage.JAVA_SCRIPT,
            DocumentLanguage.KOTLIN,
            DocumentLanguage.SWIFT,
            DocumentLanguage.C_PLUS_PLUS,
            DocumentLanguage.JAVA,
            DocumentLanguage.C_SHARP,
            DocumentLanguage.GO,
            DocumentLanguage.RUST,
            DocumentLanguage.DART,
            DocumentLanguage.PHP,
            DocumentLanguage.WEB,
            DocumentLanguage.JSON,
            -> listOf("//")
            DocumentLanguage.CSS,
            DocumentLanguage.PLAIN,
            DocumentLanguage.MARKDOWN,
            -> emptyList()
        }

    private fun supportsBlockComments(language: DocumentLanguage): Boolean =
        when (language) {
            DocumentLanguage.JAVA_SCRIPT,
            DocumentLanguage.KOTLIN,
            DocumentLanguage.SWIFT,
            DocumentLanguage.C_PLUS_PLUS,
            DocumentLanguage.JAVA,
            DocumentLanguage.C_SHARP,
            DocumentLanguage.GO,
            DocumentLanguage.RUST,
            DocumentLanguage.DART,
            DocumentLanguage.PHP,
            DocumentLanguage.SQL,
            DocumentLanguage.CSS,
            DocumentLanguage.WEB,
            DocumentLanguage.JSON,
            -> true
            else -> false
        }

    private fun caseInsensitiveKeywords(language: DocumentLanguage): Boolean =
        when (language) {
            DocumentLanguage.ASSEMBLY,
            DocumentLanguage.SHELL,
            DocumentLanguage.POWERSHELL,
            DocumentLanguage.SQL,
            DocumentLanguage.YAML,
            DocumentLanguage.TOML,
            DocumentLanguage.INI,
            DocumentLanguage.DOCKERFILE,
            DocumentLanguage.HTML,
            DocumentLanguage.CSS,
            DocumentLanguage.XML,
            DocumentLanguage.WEB,
            -> true
            else -> false
        }

    private fun keywordsFor(language: DocumentLanguage): Set<String> =
        when (language) {
            DocumentLanguage.ASSEMBLY -> assemblyOps
            DocumentLanguage.JAVA_SCRIPT -> commonKeywords + javaScriptKeywords
            DocumentLanguage.KOTLIN -> commonKeywords + cLikeKeywords + kotlinKeywords
            DocumentLanguage.SWIFT -> commonKeywords + swiftKeywords
            DocumentLanguage.PYTHON -> commonKeywords + pythonKeywords
            DocumentLanguage.C_PLUS_PLUS -> commonKeywords + cLikeKeywords + cppKeywords
            DocumentLanguage.JAVA -> commonKeywords + cLikeKeywords + javaKeywords
            DocumentLanguage.C_SHARP -> commonKeywords + cLikeKeywords + cSharpKeywords
            DocumentLanguage.GO -> commonKeywords + goKeywords
            DocumentLanguage.RUST -> commonKeywords + rustKeywords
            DocumentLanguage.DART -> commonKeywords + cLikeKeywords + dartKeywords
            DocumentLanguage.PHP -> commonKeywords + phpKeywords
            DocumentLanguage.RUBY -> commonKeywords + rubyKeywords
            DocumentLanguage.SHELL -> shellKeywords
            DocumentLanguage.POWERSHELL -> commonKeywords + powerShellKeywords
            DocumentLanguage.SQL -> sqlKeywords
            DocumentLanguage.YAML,
            DocumentLanguage.TOML,
            DocumentLanguage.INI,
            DocumentLanguage.DOCKERFILE,
            -> configKeywords
            DocumentLanguage.HTML,
            DocumentLanguage.CSS,
            DocumentLanguage.XML,
            DocumentLanguage.WEB,
            DocumentLanguage.JSON,
            -> commonKeywords + markupKeywords
            DocumentLanguage.PLAIN,
            DocumentLanguage.MARKDOWN,
            -> emptySet()
        }

    private fun words(value: String): Set<String> =
        value.trimIndent().split(Regex("\\s+")).filter { it.isNotBlank() }.toSet()

    private val assemblyOps = words(
        """
        mov lea push pop call ret jmp je jne jz jnz ja jae jb jbe jl jle jg jge
        cmp test add sub inc dec mul imul div idiv and or xor not shl shr sal sar
        rol ror nop int syscall sysenter leave enter rep repe repne stosb stosw
        stosd movsb movsw movsd lodsb lodsw lodsd scasb scasw scasd cmpsb cmpsw
        cmpsd db dw dd dq section global extern bits org equ
        """,
    )

    private val commonKeywords = words(
        """
        if else for while do switch case default break continue return throw try catch finally
        true false null nil none yes no on off
        """,
    )

    private val cLikeKeywords = words(
        """
        class interface enum struct public private protected static final abstract override
        void int long short byte char float double bool boolean string new this super extends
        implements import package namespace using const var let
        """,
    )

    private val javaScriptKeywords = words(
        """
        const let var function class import export from async await typeof undefined yield
        interface type extends implements readonly keyof declare module require
        """,
    )

    private val kotlinKeywords = words(
        """
        fun val var object data sealed companion suspend inline reified when is in as null
        package import open internal lateinit by get set
        """,
    )

    private val swiftKeywords = words(
        """
        func let var class struct enum protocol extension guard defer inout throws async await
        actor associatedtype where self Self import public private fileprivate internal open
        """,
    )

    private val pythonKeywords = words(
        """
        def lambda pass in is and or not from import as with yield global nonlocal elif except
        raise assert del True False None async await class
        """,
    )

    private val cppKeywords = words(
        """
        template typename include define ifdef ifndef endif pragma auto constexpr noexcept nullptr
        virtual friend operator unsigned signed size_t std
        """,
    )

    private val javaKeywords = words("record sealed permits synchronized volatile transient native strictfp throws instanceof")

    private val cSharpKeywords = words(
        """
        var dynamic readonly ref out in params async await namespace using get set init partial
        record sealed virtual override event delegate where yield nameof nullable
        """,
    )

    private val goKeywords = words(
        """
        package import func defer go chan select range map interface struct type var const iota
        fallthrough nil make new append cap close complex copy delete imag len panic print println real recover
        """,
    )

    private val rustKeywords = words(
        """
        fn let mut pub crate mod use impl trait enum struct async await match if let loop move
        ref self Self super unsafe where dyn const static type Some None Ok Err Result Option
        """,
    )

    private val dartKeywords = words(
        """
        class mixin extension import export part async await yield late required final const var
        dynamic typedef factory implements with library nullable true false null
        """,
    )

    private val phpKeywords = words(
        """
        php echo function namespace use class trait interface extends implements public private
        protected static final abstract var yield match fn array null true false
        """,
    )

    private val rubyKeywords = words(
        """
        def end class module require include extend attr_reader attr_writer attr_accessor begin rescue
        ensure elsif unless until yield self nil true false do
        """,
    )

    private val shellKeywords = words(
        """
        if then else elif fi for while until do done case esac function select in export local
        readonly unset shift source alias test true false
        """,
    )

    private val powerShellKeywords = words(
        """
        function param process begin end if elseif else foreach for while do switch try catch finally
        throw return break continue filter workflow class enum using namespace true false null
        """,
    )

    private val sqlKeywords = words(
        """
        select from where join inner left right full outer on group by order having insert into update
        delete create alter drop table view index primary foreign key references constraint values set
        null not and or as distinct union all limit offset case when then else end
        """,
    )

    private val markupKeywords = words(
        """
        html head body div span script style link meta title section article header footer nav main
        form input button table tr td th ul ol li svg path rect circle viewBox xmlns
        """,
    )

    private val configKeywords = words(
        """
        true false null yes no on off version services image build ports volumes environment command
        from run copy add cmd entrypoint expose workdir user arg env label maintainer
        """,
    )
}
