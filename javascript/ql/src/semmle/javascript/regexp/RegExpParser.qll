import javascript
import Tokenizer

module Token {
  abstract class RegExpToken extends TokenType {
    bindingset[this, prio] RegExpToken() { any() }
  }

  abstract class CharClassToken extends TokenType {
    bindingset[this, prio] CharClassToken() { any() }
  }

  class LookaroundAssertionStart extends RegExpToken, LiteralTokenType {
    LookaroundAssertionStart() {
      (
        this = "(?=" or this = "(?!" or
        this = "(?<=" or this = "(?<!"
      ) and
      prio = 0
    }
  }

  class NonCaptureGroupStart extends RegExpToken, LiteralTokenType {
    NonCaptureGroupStart() { this = "(?:" and prio = 1 }
  }

  class NamedCaptureGroupStart extends RegExpToken {
    NamedCaptureGroupStart() { this = "\\(\\?<(\\w+)>" and prio = 1 }
  }

  abstract class EscapeSequence extends RegExpToken, CharClassToken {
    bindingset[this, prio] EscapeSequence() { any() }
  }

  class HexEscape extends EscapeSequence {
    HexEscape() { this = "\\\\x[0-9a-fA-F]{2}" and prio = 2 }
  }

  class UnicodeEscape extends EscapeSequence {
    UnicodeEscape() { this = "\\\\u([0-9a-fA-F]{4}|\\{[0-9a-fA-F]+\\})" and prio = 2 }
  }

  class NamedBackref extends EscapeSequence {
    NamedBackref() { this = "\\\\k<\\w+>" and prio = 2 }
  }

  class UnicodePropertyEscape extends EscapeSequence {
    UnicodePropertyEscape() { this = "\\\\[pP]\\{[\\w]+(=\\w*)?\\}" and prio = 2 }
  }

  class DecimalEscape extends EscapeSequence {
    DecimalEscape() { this = "\\\\[0-9]+" and prio = 2 }
  }

  class ControlEscape extends EscapeSequence {
    ControlEscape() { this = "\\\\c[a-zA-Z]" and prio = 2 }
  }

  class OtherEscape extends EscapeSequence {
    OtherEscape() { this = "\\\\[^0-9]" and prio = 3 }
  }

  class CharClass extends RegExpToken {
    CharClass() { this = "\\[(\\\\.|[^\\\\\\]])*\\]" and prio = 4 }
  }

  class RangeQuantifier extends RegExpToken {
    RangeQuantifier() { this = "\\{\\d+(,\\d*)?\\}" and prio = 5 }
  }

  class PatternChar extends RegExpToken, CharClassToken {
    PatternChar() { this = "." and prio = 6 }
  }

  class End extends RegExpToken {
    End() { this = "$" and prio = 6 }
  }
}

class RegExpTokenizer extends Tokenizer {
  RegExpTokenizer() { this = "RegExpTokenizer" }

  override TokenType getATokenType() { result instanceof Token::RegExpToken }
}

class CharClassTokenizer extends Tokenizer {
  CharClassTokenizer() { this = "CharClassTokenizer" }

  override TokenType getATokenType() { result instanceof Token::CharClassToken }
}

abstract class RegExpSource extends SourceString {
  bindingset[this] RegExpSource() { any() }

  override Tokenizer getTokenizer() { result instanceof RegExpTokenizer }

  RegExp::Term parse() {
    result = parseDisjunction(0, _, "")
  }

  RegExp::Term parseDisjunction(int start, int end, string next) {
    disjunctionStart(start) and
    result = parseAlternative(start, end, next) and
    next != "|"
    or
    result = RegExp::TDisjunction(this, start, end, _, _, next)
  }

  predicate disjunctionStart(int start) {
    start = 0 or
    tokenAt(start-1, "|") or
    tokenAt(start-1, _, any(Token::LookaroundAssertionStart t)) or
    tokenAt(start-1, "(") or
    tokenAt(start-1, _, any(Token::NamedCaptureGroupStart t)) or
    tokenAt(start-1, _, any(Token::NonCaptureGroupStart t))
  }

  RegExp::Term parseAlternative(int start, int end, string next) {
    result = RegExp::TEmpty(this, start, next) and
    end = start
    or
    result = parseTerm(start, end) and
    exists(RegExp::TEmpty(this, end, next))
    or
    result = RegExp::TSequence(this, start, end, _, _, next)
  }

  RegExp::Term parseTerm(int start, int end) {
    result = RegExp::TCaret(this, start) and end = start+1
    or
    result = RegExp::TDollar(this, start) and end = start+1
    or
    result = RegExp::TWordBoundaryAssertion(this, start) and end = start+1
    or
    result = RegExp::TLookaroundAssertion(this, start, end, _)
    or
    result = parseQuantified(start, end)
  }

  pragma[noinline]
  predicate parseLookaroundAssertionStart(int start, int end) {
    tokenAt(start, _, any(Token::LookaroundAssertionStart l)) and
    end = start+1
  }

  RegExp::Term parseQuantified(int start, int end) {
    result = RegExp::TQuantified(this, start, end, _, _, _)
    or
    result = parseAtom(start, end) and
    not parseQuantifier(end, _, _, _)
  }

  predicate parseQuantifier(int start, int end, string quant, boolean eager) {
    tokenAt(start, quant) and
    (
      quant = "*" or quant = "+" or quant = "?" or
      exists (Token::RangeQuantifier rq | quant.regexpMatch(rq.regexp()))
    ) and
    if tokenAt(start+1, "?") then
      (eager = false and end = start+2)
    else
      (eager = true and end = start+1)
  }

  RegExp::Term parseAtom(int start, int end) {
    result = RegExp::TDot(this, start) and end = start+1
    or
    result = RegExp::THexEscape(this, start, _) and end = start+1
    or
    result = RegExp::TUnicodeEscape(this, start, _) and end = start+1
    or
    result = RegExp::TNamedBackref(this, start, _) and end = start+1
    or
    result = RegExp::TUnicodePropertyEscape(this, start, _) and end = start+1
    or
    result = RegExp::TDecimalEscape(this, start, _) and end = start+1
    or
    result = RegExp::TControlEscape(this, start, _) and end = start+1
    or
    result = RegExp::TOtherEscape(this, start, _) and end = start+1
    or
    result = RegExp::TCharClass(this, start) and end = start+1
    or
    result = RegExp::TGroup(this, start, end, _)
    or
    result = RegExp::TPatternChar(this, start) and end = start+1
  }

  predicate parseGroupStart(int start, int end) {
    (
      tokenAt(start, "(") or
      tokenAt(start, _, any(Token::NonCaptureGroupStart s)) or
      tokenAt(start, _, any(Token::NamedCaptureGroupStart s))
    ) and
    end = start+1
  }
}

class CharClassSource extends SourceString {
  RegExpSource res;
  int start;
  boolean inverted;

  CharClassSource() {
    exists (string cc, int ccstart | res.token(_, ccstart, "[" + cc + "]") |
      if cc.charAt(0) = "^" then (
        inverted = true and start = ccstart+2 and this = cc.suffix(1)
      ) else (
        inverted = false and start = ccstart+1 and this = cc
      )
    )
  }

  override Tokenizer getTokenizer() { result instanceof CharClassTokenizer }

  override predicate hasLocationInfo(string path, int startLine, int startColumn, int endLine, int endColumn) {
    res.hasLocationInfo(path, startLine, startColumn-start, _, _) and
    endLine = startLine and
    endColumn = startColumn + length()
  }

  predicate parse() {
    parseBodyElements(0)
  }

  predicate parseBodyElements(int begin) {
    tokenAt(begin, "")
    or
    exists (int end |
      parseBodyElement(begin, end) and
      parseBodyElements(end)
    )
  }

  predicate parseBodyElement(int begin, int end) {
    parseClassAtom(begin) and
    end = begin+1
    or
    parseClassAtom(begin) and
    tokenAt(begin+1, "-") and
    parseClassAtom(begin+2) and
    end = begin+3
  }

  predicate parseClassAtom(int begin) {
    exists (string val |
      tokenAt(begin, val) and
      val != "-"
    )
    or
    tokenAt(begin, "-") and
    dashIsLiteral(begin)
  }

  predicate dashIsLiteral(int pos) {
    pos = 0
    or
    tokenAt(pos+1, "")
    or
    tokenAt(pos-1, "-") and
    dashIsLiteral(pos-2)
  }
}

module RegExp {
  newtype TTerm =
    TDot(RegExpSource src, int pos) { src.tokenAt(pos, ".") }
    or
    THexEscape(SourceString src, int pos, string val) {
      (src instanceof RegExpSource or src instanceof CharClassSource) and
      src.tokenAt(pos, val, any(Token::HexEscape h))
    }
    or
    TUnicodeEscape(SourceString src, int pos, string val) {
      (src instanceof RegExpSource or src instanceof CharClassSource) and
      src.tokenAt(pos, val, any(Token::UnicodeEscape h))
    }
    or
    TNamedBackref(RegExpSource src, int pos, string val) {
      src.tokenAt(pos, val, any(Token::NamedBackref h))
    }
    or
    TUnicodePropertyEscape(SourceString src, int pos, string val) {
      (src instanceof RegExpSource or src instanceof CharClassSource) and
      src.tokenAt(pos, val, any(Token::UnicodePropertyEscape h))
    }
    or
    TDecimalEscape(SourceString src, int pos, string val) {
      (src instanceof RegExpSource or src instanceof CharClassSource) and
      src.tokenAt(pos, val, any(Token::DecimalEscape h))
    }
    or
    TControlEscape(SourceString src, int pos, string val) {
      (src instanceof RegExpSource or src instanceof CharClassSource) and
      src.tokenAt(pos, val, any(Token::ControlEscape h))
    }
    or
    TOtherEscape(SourceString src, int pos, string val) {
      (src instanceof RegExpSource or src instanceof CharClassSource) and
      src.tokenAt(pos, val, any(Token::OtherEscape h))
    }
    or
    TCharClass(RegExpSource src, int pos) { src.tokenAt(pos, _, any(Token::CharClass cc)) }
    or
    TGroup(RegExpSource src, int start, int end, Term body) {
      exists (int mid |
        src.parseGroupStart(start, mid) and
        body = src.parseDisjunction(mid, end-1, ")")
      )
    }
    or
    TPatternChar(SourceString src, int pos) {
      (src instanceof RegExpSource or src instanceof CharClassSource) and
      exists (string v |
        src.tokenAt(pos, v) and
        v.regexpMatch("[^\\^$\\\\.*+?|()\\[\\]]")
      )
    }
    or
    TQuantified(RegExpSource src, int start, int end, Term body, string quant, boolean eager) {
      exists (int atomEnd |
        body = src.parseAtom(start, atomEnd) and
        src.parseQuantifier(atomEnd, end, quant, eager)
      )
    }
    or
    TCaret(RegExpSource src, int pos) { src.tokenAt(pos, "^") }
    or
    TDollar(RegExpSource src, int pos) { src.tokenAt(pos, "$") }
    or
    TLookaroundAssertion(RegExpSource src, int start, int end, Term body) {
      exists (int mid |
        src.parseLookaroundAssertionStart(start, mid) and
        body = src.parseDisjunction(mid, end-1, ")")
      )
    }
    or
    TEmpty(RegExpSource src, int start, string next) {
      src.tokenAt(start, next) and
      (next = "" or next = "|" or next = ")")
    }
    or
    TSequence(RegExpSource src, int start, int end, Term left, Term right, string next) {
      exists (int mid |
        left = src.parseTerm(start, mid) and
        right = src.parseAlternative(mid, end, next) and
        not right instanceof TEmpty
      )
    }
    or
    TDisjunction(RegExpSource src, int start, int end, Term left, Term right, string next) {
      exists (int mid |
        src.disjunctionStart(start) and
        left = src.parseAlternative(start, mid, "|") and
        right = src.parseDisjunction(mid+1, end, next)
      )
    }

  predicate spansTokens(TTerm t, RegExpSource src, int startTk, int endTk) {
    t = TDot(src, startTk) and endTk = startTk + 1
    or
    t = THexEscape(src, startTk, _) and endTk = startTk + 1
    or
    t = TUnicodeEscape(src, startTk, _) and endTk = startTk + 1
    or
    t = TNamedBackref(src, startTk, _) and endTk = startTk + 1
    or
    t = TUnicodePropertyEscape(src, startTk, _) and endTk = startTk + 1
    or
    t = TDecimalEscape(src, startTk, _) and endTk = startTk + 1
    or
    t = TControlEscape(src, startTk, _) and endTk = startTk + 1
    or
    t = TOtherEscape(src, startTk, _) and endTk = startTk + 1
    or
    t = TCharClass(src, startTk) and endTk = startTk + 1
    or
    t = TGroup(src, startTk, endTk, _)
    or
    t = TPatternChar(src, startTk) and endTk = startTk + 1
    or
    t = TQuantified(src, startTk, endTk, _, _, _)
    or
    t = TCaret(src, startTk) and endTk = startTk + 1
    or
    t = TDollar(src, startTk) and endTk = startTk + 1
    or
    t = TWordBoundaryAssertion(src, startTk) and endTk = startTk + 1
    or
    t = TLookaroundAssertion(src, startTk, endTk, _)
    or
    t = TEmpty(src, startTk, _) and endTk = startTk
    or
    t = TSequence(src, startTk, endTk, _, _, _)
    or
    t = TDisjunction(src, startTk, endTk, _, _, _)
  }

  int tokenStart(RegExpSource src, int token) {
    src.token(token, result, _)
  }

  pragma[noinline]
  predicate hasLocationAux(TTerm t, RegExpSource src, int start, int endTk) {
    exists (int startTk | spansTokens(t, src, startTk, endTk) |
      start = tokenStart(src, startTk)
    )
  }

  predicate hasLocation(TTerm t, RegExpSource src, int start, int end) {
    exists (int endTk |
      hasLocationAux(t, src, start, endTk) and
      end = tokenStart(src, endTk)-1
    )
  }

  abstract class Term extends TTerm {
    predicate hasLocationInfo(string filePath, int startLine, int startColumn, int endLine, int endColumn) {
      exists (RegExpSource src, int startOffset, int endOffset, int srcStart |
        hasLocation(this, src, startOffset, endOffset) and
        src.hasLocationInfo(filePath, startLine, srcStart, endLine, _) and
        startColumn = srcStart + startOffset and
        endColumn = srcStart + endOffset
      )
    }

    string toString() {
      exists (RegExpSource src, int start, int end |
        hasLocation(this, src, start, end) and
        result = src.substring(start, end+1)
      )
    }

    RegExpTerm map() {
      none()
    }
  }

  class Dot extends Term, TDot {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.(RegExpDot).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  abstract class AtomEscape extends Term {
  }

  class HexEscape extends AtomEscape, THexEscape {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        result.(RegExpHexEscape).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class UnicodeEscape extends AtomEscape, TUnicodeEscape {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        result.(RegExpUnicodeEscape).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class NamedBackref extends AtomEscape, TNamedBackref {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        result.(RegExpBackRef).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class UnicodePropertyEscape extends AtomEscape, TUnicodePropertyEscape {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        result.(RegExpUnicodePropertyEscape).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class DecimalEscape extends AtomEscape, TDecimalEscape {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        result.(RegExpDecimalEscape).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) or
        result.(RegExpBackRef).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class ControlEscape extends AtomEscape, TControlEscape {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        result.(RegExpControlEscape).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class OtherEscape extends AtomEscape, TOtherEscape {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        escapeLocation(result, filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  predicate escapeLocation(RegExpTerm location, string filePath, int startLine, int startColumn, int endLine, int endColumn) {
    (location instanceof RegExpIdentityEscape or
     location instanceof RegExpCharacterClassEscape or
     location instanceof RegExpControlEscape) and
    location.getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
  }

  class CharClass extends Term, TCharClass {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        // TODO: match value
        result.(RegExpCharacterClass).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class Group extends Term, TGroup {
    Term body;

    Group() { this = TGroup(_, _, _, body) }

    override RegExpTerm map() {
      result.(RegExpGroup).getAChild() = body.map()
    }
  }

  class PatternChar extends Term, TPatternChar {
    string getValue() {
      exists (RegExpSource src, int pos |
        this = TPatternChar(src, pos) and
        src.tokenAt(pos, result)
      )
    }

    predicate valueAndLocation(string value, string filePath, int startLine, int startColumn) {
      value = getValue() and
      hasLocationInfo(filePath, startLine, startColumn, _, _)
    }

    override RegExpTerm map() {
      exists (string value, string filePath, int startLine, int startColumn |
        this.valueAndLocation(value, filePath, startLine, startColumn) and
        valueAndLocation(result, value, filePath, startLine, startColumn)
      )
    }
  }

  predicate valueAndLocation(RegExpNormalChar c, string value, string filePath, int startLine, int startColumn) {
    value = c.getValue() and
    c.getLocation().hasLocationInfo(filePath, startLine, startColumn, _, _)
   }

  class Quantified extends Term, TQuantified {
    Term body;
    string quant;
    boolean eager;

    Quantified() { this = TQuantified(_, _, _, body, quant, eager) }

    override RegExpTerm map() {
      result.(RegExpQuantifier).getAChild() = body.map()
      // TODO: match quantifier
    }
  }

  class Caret extends Term, TCaret {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.(RegExpCaret).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class Dollar extends Term, TDollar {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.(RegExpDollar).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class WordBoundary extends Term, TWordBoundaryAssertion {
    WordBoundary() {
      exists (RegExpSource src, int pos |
        this = TWordBoundaryAssertion(src, pos) and
        src.tokenAt(pos, "\\b")
      )
    }

    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.(RegExpWordBoundary).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class NonWordBoundary extends Term, TWordBoundaryAssertion {
    NonWordBoundary() {
      exists (RegExpSource src, int pos |
        this = TWordBoundaryAssertion(src, pos) and
        src.tokenAt(pos, "\\B")
      )
    }

    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.(RegExpNonWordBoundary).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class LookaroundAssertion extends Term, TLookaroundAssertion {
    Term body;

    LookaroundAssertion() { this = TLookaroundAssertion(_, _, _, body) }

    override RegExpTerm map() {
      result.(RegExpLookahead).getAChild() = body.map() or
      result.(RegExpLookbehind).getAChild() = body.map()
    }
  }

  class Empty extends Term, TEmpty {
    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.(RegExpSequence).getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn)
      )
    }
  }

  class Sequence extends Term, TSequence {
    Term left;
    Term right;

    Sequence() { this = TSequence(_, _, _, left, right, _) }

    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result = map(0, result.getNumChild()-1)
      )
    }

    RegExpSequence map(int start, int end) {
      result.getChild(start) = left.map() and
      (
        end = start+1 and
        end = result.getNumChild()-1 and
        result.getChild(end) = right.map()
        or
        result = right.(Sequence).map(start+1, end)
      )
    }
  }

  class Disjunction extends Term, TDisjunction {
    Term left;
    Term right;

    Disjunction() { this = TDisjunction(_, _, _, left, right, _) }

    override RegExpTerm map() {
      exists (string filePath, int startLine, int startColumn, int endLine, int endColumn |
        this.hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result.getLocation().hasLocationInfo(filePath, startLine, startColumn, endLine, endColumn) and
        result = map(0, result.getNumChild()-1)
      )
    }

    RegExpAlt map(int start, int end) {
      result.getChild(start) = left.map() and
      (
        end = start+1 and
        end = result.getNumChild()-1 and
        result.getChild(end) = right.map()
        or
        result = right.(Disjunction).map(start+1, end)
      )
    }
  }
}

class RegExpSourceFromLiteral extends RegExpSource {
  RegExpLiteral rel;

  RegExpSourceFromLiteral() {
    this = rel.getValue().regexpCapture("/(.*)/[^/]*", 1) and
    not exists(RegExpParseError err | rel = err.getLiteral())
  }

  override predicate hasLocationInfo(string path, int startLine, int startColumn, int endLine, int endColumn) {
    rel.getLocation().hasLocationInfo(path, startLine, startColumn-1, endLine, endColumn+rel.getFlags().length()+1)
  }
}
