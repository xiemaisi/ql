import RegExpParser

//class TestSource extends RegExpSource {
//  TestSource() { this = " |}|;|^" }
//  override predicate hasLocationInfo(string path, int startLine, int startColumn, int endLine, int endColumn) {
//    path = "" and startLine = 0 and startColumn = 0 and endLine = 0 and endColumn = 0
//  }
//}

//from RegExpSource src, int idx, int start, string val
//where token(src, idx, start, val) and
//      src = " |}|;|^"
//select src, idx, start, val

//from RegExpSource src, RegExp::Term t, int start, int end
//where RegExp::hasLocation(t, src, start, end) and
//      src = " |}|;|^"
//select t, t.getAQlClass(), start, end

from RegExp::Term t
where not exists(t.map()) and
      not t instanceof RegExp::Empty and
      not (t instanceof RegExp::Sequence and exists(RegExp::TSequence(_, _, _, _, t, _))) and
      not (t instanceof RegExp::Disjunction and exists(RegExp::TDisjunction(_, _, _, _, t, _)))
select t, t.getAQlClass()

//from RegExpTerm t
//where not exists (RegExp::Term tt | t = tt.map()) and
//      not exists (RegExpCharacterClass cc |
//        t = cc.getAChild() or
//        t = cc.getAChild().(RegExpCharacterRange).getAChild()
//      ) and
//      not exists (RegExpParseError pe | pe.getLiteral() = t.getLiteral())
//select t
