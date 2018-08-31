import javascript

abstract class Tokenizer extends string {
  bindingset[this] Tokenizer() { any() }
  abstract TokenType getATokenType();
}

abstract class TokenType extends string {
  int prio;

  bindingset[this, prio] TokenType() { any() }

  string regexp() { result = this }
  int priority() { result = prio }
}

abstract class SourceString extends string {
  bindingset[this] SourceString() { any() }

  abstract predicate hasLocationInfo(string path, int startLine, int startColumn, int endLine, int endColumn);

  abstract Tokenizer getTokenizer();

  private string tokenRegex() {
    exists (Tokenizer tokenizer | tokenizer = getTokenizer() |  
      result = strictconcat(TokenType tk |
        tk = tokenizer.getATokenType() |
        tk.regexp(), "|" order by tk.priority()
      )
    )
  }

  predicate token(int idx, int start, string val) {
    val = this.regexpFind(tokenRegex(), idx, start)
  }

  predicate tokenAt(int idx, string val) {
    token(idx, _, val)
  }

  predicate tokenAt(int idx, string val, TokenType tt) {
    tokenAt(idx, val) and
    val.regexpMatch(tt.regexp())
  }
}

abstract class LiteralTokenType extends TokenType {
  bindingset[this, prio] LiteralTokenType() { any() }

  bindingset[this]
  override string regexp() { result = "\\Q" + this + "\\E" }
}
