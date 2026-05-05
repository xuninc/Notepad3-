import Foundation

enum NoteLanguage: String, Codable, CaseIterable {
    case plain = "Plain"
    case markdown = "Markdown"
    case assembly = "Assembly"
    case javaScript = "JavaScript"
    case kotlin = "Kotlin"
    case swift = "Swift"
    case python = "Python"
    case cPlusPlus = "C++"
    case html = "HTML"
    case css = "CSS"
    case xml = "XML"
    case web = "Web"
    case json = "JSON"

    static let selectableLanguages: [NoteLanguage] = [
        .plain,
        .markdown,
        .json,
        .html,
        .css,
        .web,
        .javaScript,
        .kotlin,
        .swift,
        .python,
        .cPlusPlus,
        .xml,
        .assembly,
    ]

    static func detect(fromFileName name: String) -> NoteLanguage {
        let lower = name.lowercased()
        if lower.range(of: #"\.(asm|s|nasm|masm|inc)$"#, options: .regularExpression) != nil { return .assembly }
        if lower.range(of: #"\.(md|markdown)$"#, options: .regularExpression) != nil { return .markdown }
        if lower.range(of: #"\.(js|jsx|ts|tsx|mjs|cjs)$"#, options: .regularExpression) != nil { return .javaScript }
        if lower.range(of: #"\.(kt|kts)$"#, options: .regularExpression) != nil { return .kotlin }
        if lower.range(of: #"\.swift$"#, options: .regularExpression) != nil { return .swift }
        if lower.range(of: #"\.(py|pyw)$"#, options: .regularExpression) != nil { return .python }
        if lower.range(of: #"\.(c|cc|cpp|cxx|h|hh|hpp|hxx)$"#, options: .regularExpression) != nil { return .cPlusPlus }
        if lower.range(of: #"\.(html|htm)$"#, options: .regularExpression) != nil { return .html }
        if lower.range(of: #"\.css$"#, options: .regularExpression) != nil { return .css }
        if lower.range(of: #"\.(xml|svg)$"#, options: .regularExpression) != nil { return .xml }
        if lower.range(of: #"\.(json|jsonc)$"#, options: .regularExpression) != nil { return .json }
        return .plain
    }

    /// Keywords that trigger keyword styling. Empty for languages with no keyword set
    /// (plain, markdown).
    var keywords: Set<String> {
        switch self {
        case .assembly:
            return Self.assemblyOps
        case .javaScript, .kotlin, .swift, .python, .cPlusPlus, .html, .css, .xml, .web, .json:
            return Self.codeKeywords
        default:
            return []
        }
    }

    var registers: Set<String> {
        self == .assembly ? Self.assemblyRegisters : []
    }

    /// Comment-prefix patterns (anchored to start-of-substring) used by the highlighter.
    var commentPrefixes: [String] {
        switch self {
        case .assembly: return [";"]
        case .python: return ["#"]
        case .html, .xml: return ["<!--"]
        case .javaScript, .kotlin, .swift, .cPlusPlus, .web, .json: return ["//"]
        default: return []
        }
    }

    var supportsBlockComments: Bool {
        switch self {
        case .javaScript, .kotlin, .swift, .cPlusPlus, .css, .web, .json:
            return true
        default:
            return false
        }
    }

    private static let assemblyOps: Set<String> = Set("""
        mov lea push pop call ret jmp je jne jz jnz ja jae jb jbe jl jle jg jge \
        cmp test add sub inc dec mul imul div idiv and or xor not shl shr sal sar \
        rol ror nop int syscall sysenter leave enter rep repe repne stosb stosw \
        stosd movsb movsw movsd lodsb lodsw lodsd scasb scasw scasd cmpsb cmpsw \
        cmpsd db dw dd dq section global extern bits org equ
        """.split(separator: " ").map(String.init))

    private static let assemblyRegisters: Set<String> = Set("""
        al ah ax eax rax bl bh bx ebx rbx cl ch cx ecx rcx dl dh dx edx rdx \
        si esi rsi di edi rdi sp esp rsp bp ebp rbp r8 r9 r10 r11 r12 r13 r14 r15 \
        r8d r9d r10d r11d r12d r13d r14d r15d xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7 \
        ymm0 ymm1 ymm2 ymm3 ymm4 ymm5 ymm6 ymm7 cs ds es fs gs ss
        """.split(separator: " ").map(String.init))

    private static let codeKeywords: Set<String> = Set("""
        const let var function return if else for while switch case break continue \
        class import export from async await try catch finally throw new typeof \
        interface type extends def lambda pass in is and or not true false null \
        undefined None True False public private protected static void int char \
        float double bool string fun val struct enum protocol guard let var mut \
        package namespace using template typename include define ifdef endif
        """.split(separator: " ").map(String.init))
}
