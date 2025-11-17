import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros


public struct StaticCStringMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        let expandedCode = """
        (unsafeBitCast(StaticString(\(node.arguments.first!.expression)).utf8Start, to: UnsafePointer<CChar>.self), StaticString(\(node.arguments.first!.expression)).utf8CodeUnitCount)
        """
        
        return "\(raw: expandedCode)" as ExprSyntax
    }
}





public struct ZvalUndefMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        
        // Ensure there's an argument passed
        guard let argument = node.arguments.first?.expression else {
            throw CustomError.message("Expected argument.")
        }

        // Construct the Swift code equivalent for the C macro using `withUnsafeMutablePointer`
        let expandedCode = """
        do {
            withUnsafeMutablePointer(to: \(argument)) { ptr in
                ptr.pointee.u1.type_info = 0
            }
        }
        """
        
        // Return the expanded Swift code
        return "\(raw: expandedCode)"
    }
}

enum CustomError: Error { case message(String) }

@main
struct PhpMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ZvalUndefMacro.self,
        StaticCStringMacro.self
    ]
}